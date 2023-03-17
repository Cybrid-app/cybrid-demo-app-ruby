# frozen_string_literal: true

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
