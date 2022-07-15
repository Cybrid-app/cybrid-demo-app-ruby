# frozen_string_literal: true

require 'jwt'
require 'securerandom'

def create_rsa_key
  size = 2048
  exponent = 65_537
  OpenSSL::PKey::RSA.generate(size, exponent)
end

def create_jwt(rsa_key, verification_key, customer, bank_guid)
  header = {
    alg: 'RS512',
    kid: verification_key.guid
  }

  issued_at = DateTime.now
  expired_at = issued_at.next_year
  claims = {
    iss: "http://api.cybrid.app/banks/#{bank_guid}",
    aud: 'http://api.cybrid.app',
    sub: "http://api.cybrid.app/customers/#{customer.guid}",
    iat: issued_at.to_time.utc.to_i,
    exp: expired_at.to_time.utc.to_i,
    jti: SecureRandom.uuid
  }

  payload = {
    **claims
  }

  JWT.encode(payload, rsa_key, 'RS512', header)
end

# Lazily evaluated String
# The String value of a LazyStr is evaluated only when the object is converted to a String, rather than at
# initialization time.
class LazyStr
  def initialize(&block)
    @block = block
  end

  def to_s
    @block.call.to_s
  end
end
