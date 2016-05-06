# -*- encoding: utf-8 -*-
require 'rumoji'
require 'benchmark/ips'

module Original
  module Rumoji
    extend self

    def decode(str)
      str.gsub(/:([^\s:]?[\w-]+):/) {|sym| (Emoji.find($1.intern) || sym).to_s }
    end
  end

  class Emoji < ::Rumoji::Emoji
    def include?(symbol)
      @cheat_codes.include? symbol.to_sym
    end

    ALL = ::Rumoji::Emoji::ALL.map do |emoji|
      Emoji.new(emoji.string, emoji.instance_variable_get(:@cheat_codes), emoji.name)
    end

    def self.find(symbol)
      ALL.find {|emoji| emoji.include? symbol }
    end
  end
end


module AvoidSymbols
  module Rumoji
    extend self

    def decode(str)
      str.gsub(/:([^\s:]?[\w-]+):/) {|sym| (Emoji.find($1) || sym).to_s }
    end
  end

  class Emoji < ::Rumoji::Emoji
    def initialize(string, symbols, name = nil)
      super
      @cheat_code_strings = @cheat_codes.map(&:to_s)
    end

    def include?(symbol)
      @cheat_code_strings.include? symbol.to_s
    end

    ALL = ::Rumoji::Emoji::ALL.map do |emoji|
      Emoji.new(emoji.string, emoji.instance_variable_get(:@cheat_codes), emoji.name)
    end

    def self.find(symbol)
      ALL.find {|emoji| emoji.include? symbol }
    end
  end
end


module CachedFind
  module Rumoji
    extend self

    def decode(str)
      str.gsub(/:([^\s:]?[\w-]+):/) { |sym| (Emoji.find($1) || sym).to_s }
    end
  end

  class Emoji < ::Rumoji::Emoji
    def include?(symbol)
      @cheat_codes.map(&:to_s).include? symbol.to_s
    end

    ALL = ::Rumoji::Emoji::ALL.map do |emoji|
      Emoji.new(emoji.string, emoji.instance_variable_get(:@cheat_codes), emoji.name)
    end

    CODE_LOOKUP = {}

    def self.find(symbol)
      symbol = symbol.to_s
      CODE_LOOKUP[symbol] ||= ALL.find {|emoji| emoji.include? symbol }
    end
  end
end


module PrecomputeStringLookup
  module Rumoji
    extend self

    def decode(str)
      str.gsub(/:([^\s:]?[\w-]+):/) {|sym| (Emoji.find($1) || sym).to_s }
    end
  end

  class Emoji < ::Rumoji::Emoji
    def symbol
      symbols.first
    end

    def symbols
      @cheat_codes
    end

    def include?(symbol)
      symbols.map(&:to_s).include? symbol.to_s
    end

    ALL = ::Rumoji::Emoji::ALL.map do |emoji|
      Emoji.new(emoji.string, emoji.instance_variable_get(:@cheat_codes), emoji.name)
    end

    CODE_LOOKUP = ALL.each.with_object({}) do |emoji, lookup|
      emoji.symbols.each do |symbol|
        lookup[symbol.to_s] = emoji
      end
    end

    def self.find(symbol)
      CODE_LOOKUP[symbol.to_s]
    end
  end
end


module PrecomputeStringAndSymbolLookup
  module Rumoji
    extend self

    def decode(str)
      str.gsub(/:([^\s:]?[\w-]+):/) {|sym| (Emoji.find($1) || sym).to_s }
    end
  end

  class Emoji < ::Rumoji::Emoji
    def symbol
      symbols.first
    end

    def symbols
      @cheat_codes
    end

    def include?(symbol)
      symbols.map(&:to_s).include? symbol.to_s
    end

    ALL = ::Rumoji::Emoji::ALL.map do |emoji|
      Emoji.new(emoji.string, emoji.instance_variable_get(:@cheat_codes), emoji.name)
    end

    CODE_LOOKUP = ALL.each.with_object({}) do |emoji, lookup|
      emoji.symbols.each do |symbol|
        lookup[symbol.to_s] = lookup[symbol] = emoji
      end
    end

    def self.find(symbol)
      CODE_LOOKUP[symbol]
    end
  end
end


module CheatCodeRegexp
  module Rumoji
    extend self

    def decode(str)
      str.gsub(Emoji::ALL_CODES_REGEXP) { |match| (Emoji.find($1) || match).to_s }
    end
  end

  class Emoji < ::Rumoji::Emoji
    def symbol
      symbols.first
    end

    def symbols
      @cheat_codes
    end

    def include?(symbol)
      @cheat_codes.map(&:to_s).include? symbol.to_s
    end

    ALL = ::Rumoji::Emoji::ALL.map do |emoji|
      Emoji.new(emoji.string, emoji.instance_variable_get(:@cheat_codes), emoji.name)
    end

    ALL_CODES_REGEXP = Regexp.new(
      ":(" + ALL.map(&:symbols).flatten.map { |sym| Regexp.escape(sym) }.join('|') + "):"
    )

    CODE_LOOKUP = ALL.each.with_object({}) do |emoji, lookup|
      emoji.symbols.each do |symbol|
        lookup[symbol.to_s] = emoji
      end
    end

    def self.find(symbol)
      CODE_LOOKUP[symbol.to_s]
    end
  end
end


base_string = <<-BASE
  Lorem ipsum dolor sit amet, consectetur adipiscing elit. :smile: In tristique
  varius ex, eu viverra turpis faucibus sit amet. Cras sagittis pellentesque
  :heart: velit malesuada pharetra. Ut lectus arcu, vehicula :boom::punch:
  ornare tellus quis, consectetur vulputate risus. Pellentesque quis nunc
  cursus, mattis magna non, :eyes:gravida lacus. In a nisi efficitur, euismod
  ipsum eget, rutrum metus. Nulla sit amet eros sit amet nulla vestibulum
  lacinia. Vivamus :snowman: luctus ante mi, vel pretium lacus congue sed.
  Suspendisse ultricies consequat maximus. Maecenas :train: consequat in diam
  ut egestas. :no_entry_sign: this is
  :+1: and :-1: have non-word characters in them.
BASE

decoded = Rumoji::decode(base_string)

[
  Original::Rumoji,
  AvoidSymbols::Rumoji,
  CachedFind::Rumoji,
  PrecomputeStringLookup::Rumoji,
  CheatCodeRegexp::Rumoji
].each do |klass|
  if decoded != klass.decode(base_string)
    raise "#{klass}.decode() did not match Rumoji::decode()!"
  end
end

Benchmark.ips do |x|
  x.report("original: ") do
    Original::Rumoji.decode(base_string)
  end
  x.report("avoid symbols: ") do
    AvoidSymbols::Rumoji.decode(base_string)
  end
  x.report("cached find: ") do
    CachedFind::Rumoji.decode(base_string)
  end
  x.report("precompute string lookup: ") do
    PrecomputeStringLookup::Rumoji.decode(base_string)
  end
  x.report("precompute string and symbol lookup: ") do
    PrecomputeStringAndSymbolLookup::Rumoji.decode(base_string)
  end
  x.report("cheat code regexp: ") do
    CheatCodeRegexp::Rumoji.decode(base_string)
  end

  x.compare!
end
