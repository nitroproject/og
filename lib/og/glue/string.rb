class String

  alias :camelize :camelcase

  def demodulize
    gsub('::', '_')
  end

end

