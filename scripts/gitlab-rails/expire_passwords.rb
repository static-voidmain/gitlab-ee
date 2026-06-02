# frozen_string_literal: true

require 'date'
require 'json'
require 'yaml'

days = Integer(ENV.fetch('PASSWORD_EXPIRE_DAYS', '90'))
exceptions_path = ENV.fetch('PASSWORD_EXCEPTION_FILE', '/opt/gitlab-bootstrap/password-expiration-exceptions.yml')
now = Time.current
next_expiration = days.days.from_now

abort 'PASSWORD_EXPIRE_DAYS must be between 1 and 90' unless days.between?(1, 90)

raw_exceptions = File.exist?(exceptions_path) ? YAML.safe_load(File.read(exceptions_path), permitted_classes: [Date]) : {}
exceptions = Array(raw_exceptions && raw_exceptions['exceptions'])
exception_usernames = []
expired_exceptions = []
required_exception_fields = %w[username reason owner ticket expires_on].freeze

exceptions.each_with_index do |entry, index|
  abort "Exception entry #{index} must be a mapping" unless entry.is_a?(Hash)

  missing_fields = required_exception_fields.select { |field| entry[field].to_s.strip.empty? }
  abort "Exception entry #{index} is missing: #{missing_fields.join(', ')}" unless missing_fields.empty?

  begin
    expires_on = Date.iso8601(entry.fetch('expires_on').to_s)
  rescue Date::Error
    abort "Exception entry #{index} has an invalid expires_on date"
  end

  username = entry.fetch('username').to_s
  if expires_on < Date.current
    expired_exceptions << { username: username, expires_on: expires_on.iso8601 }
    next
  end

  abort "Duplicate password expiration exception: #{username}" if exception_usernames.include?(username)

  exception_usernames << username
end

scope = User.active.where(user_type: nil)
updated = []
skipped = []

scope.find_each do |user|
  bot_user = user.respond_to?(:bot?) && user.bot?
  internal_user = user.respond_to?(:internal?) && user.internal?

  if user.username == 'ghost' || bot_user || internal_user || exception_usernames.include?(user.username)
    skipped << { username: user.username, reason: 'internal_bot_or_exception' }
    next
  end

  if user.identities.exists? && ENV.fetch('PASSWORD_EXPIRE_SSO_USERS', 'false') != 'true'
    skipped << { username: user.username, reason: 'sso_identity' }
    next
  end

  # 구현상세: password_expires_at이 nil이면 다음 만료일을 설정한다.
  # 이미 과거 날짜인 사용자는 GitLab 로그인 흐름에서 비밀번호 변경을 강제하므로 유지한다.
  if user.password_expires_at.nil?
    user.update!(password_expires_at: next_expiration)
    updated << { username: user.username, password_expires_at: user.password_expires_at.iso8601 }
  elsif user.password_expires_at <= now
    skipped << { username: user.username, reason: 'already_expired', password_expires_at: user.password_expires_at.iso8601 }
  else
    skipped << { username: user.username, reason: 'already_scheduled', password_expires_at: user.password_expires_at.iso8601 }
  end
end

puts JSON.pretty_generate(
  status: 'ok',
  policy_days: days,
  expired_exception_count: expired_exceptions.length,
  expired_exceptions: expired_exceptions,
  updated_count: updated.length,
  skipped_count: skipped.length,
  updated: updated,
  skipped: skipped
)
