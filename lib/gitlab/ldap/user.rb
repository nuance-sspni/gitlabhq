# LDAP extension for User model
#
# * Find or create user from omniauth.auth data
# * Links LDAP account with existing user
# * Auth LDAP user with login and password
#
module Gitlab
  module LDAP
    class User < Gitlab::OAuth::User
      class << self
        def find_by_uid_and_provider(uid, provider)
          uid = Gitlab::LDAP::Person.normalize_dn(uid)

          identity = ::Identity
            .where(provider: provider)
            .where(extern_uid: uid).last
          identity && identity.user
        end
      end

      def save
        super('LDAP')
      end

      # instance methods
      def find_user
        find_by_uid_and_provider || find_by_email || build_new_user
      end

      def find_by_uid_and_provider
        self.class.find_by_uid_and_provider(auth_hash.uid, auth_hash.provider)
      end

      def changed?
        gl_user.changed? || gl_user.identities.any?(&:changed?)
      end

      def block_after_signup?
        ldap_config.block_auto_created_users
      end

      def sync_profile_from_provider?
        true
      end

      def allowed?
        Gitlab::LDAP::Access.allowed?(gl_user)
      end

      def ldap_config
        Gitlab::LDAP::Config.new(auth_hash.provider)
      end

      def auth_hash=(auth_hash)
        @auth_hash = Gitlab::LDAP::AuthHash.new(auth_hash)
      end
    end
  end
end
