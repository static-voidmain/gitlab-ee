# frozen_string_literal: true

require 'date'
require 'json'
require 'yaml'

days = Integer(ENV.fetch('PASSWORD_EXPIRE_DAYS', '90'))
exceptions_path = ENV.fetch('PASSWORD_EXCEPTION_FILE', '/opt/gitlab-bootstrap/password-expiration-exceptions.yml')
now = Time.current
next_expiration = days.days.from_now

raw_exceptions = File.exist?(exceptions_path) ? YAML.safe_load(File.read(exceptions_path), permitted_classes: [Date]) : {}
exceptions = Array(raw_exceptions && raw_exceptions['exceptions'])
exception_usernames = exceptions.filter_map do |entry|
  next unless entry.is_a?(Hash)

  expires_on = entry['expires_on']
  next if expires_on && Date.parse(expires_on.to_s) < Date.current

  entry['username'].to_s
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
  updated_count: updated.length,
  skipped_count: skipped.length,
  updated: updated,
  skipped: skipped
)
