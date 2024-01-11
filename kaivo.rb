module Kaivo
  def Kaivo::string_eql? s1, s2
    return( s1.length == s2.length and string_begins_with?(s1, s2) )
  end

  def Kaivo::string_begins_with? s1, s2
    (0 .. s2.length - 1).each do | i |
      return false if s2[i] != s1[i]
    end

    return true
  end
end
