# frozen_string_literal: true

require 'json'

docs_url = ENV.fetch('GITLAB_DOCS_EXTERNAL_URL') do
  abort 'GITLAB_DOCS_EXTERNAL_URL is required'
end

settings = ApplicationSetting.current

# 요구사항: Premium 비밀번호 복잡도, 로그인 실패 잠금, private 기본값, Docs redirect 적용.
# 구현상세: 버전별 미지원 setting이 있어 respond_to?로 방어적으로 적용한다.
desired_settings = {
  signup_enabled: false,
  require_admin_approval_after_user_signup: true,
  email_confirmation_setting: 'hard',
  default_project_visibility: 'private',
  default_group_visibility: 'private',
  default_snippet_visibility: 'private',
  restricted_visibility_levels: %w[public internal],
  gravatar_enabled: false,
  user_defaults_to_private_profile: true,
  help_page_hide_commercial_content: true,
  help_page_documentation_base_url: docs_url,
  enabled_git_access_protocol: 'http',
  password_authentication_enabled_for_git: true,
  password_authentication_enabled_for_web: true,
  minimum_password_length: 12,
  password_number_required: true,
  password_symbol_required: true,
  password_uppercase_required: true,
  password_lowercase_required: true,
  max_login_attempts: 5,
  failed_login_attempts_unlock_period_in_minutes: 60,
  require_personal_access_token_expiry: true,
  default_project_creation: 1,
  can_create_group: false,
  session_expire_delay: 720
}

applied = {}
skipped = {}

desired_settings.each do |name, value|
  setter = "#{name}="
  if settings.respond_to?(setter)
    settings.public_send(setter, value)
    applied[name] = value
  else
    skipped[name] = 'unsupported_by_this_gitlab_version'
  end
end

settings.save!

puts JSON.pretty_generate(
  status: 'ok',
  message: 'GitLab application settings applied',
  applied: applied,
  skipped: skipped
)
