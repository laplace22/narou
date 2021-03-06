# -*- coding: utf-8 -*-
#
# Copyright 2013 whiteleaf. All rights reserved.
#

require "fileutils"
require_relative "ini"

class NovelSetting
  INI_NAME = "setting.ini"
  REPLACE_NAME = "replace.txt"

  attr_accessor :id, :author, :title, :archive_path, :replace_pattern

  def self.load(target, ignore_force)
    archive_path = Downloader.get_novel_data_dir_by_target(target)
    if archive_path
      setting = new(archive_path, ignore_force)
      data = Downloader.get_data_by_target(target)
      setting.id = data["id"]
      setting.author = data["author"]
      setting.title = data["title"]
      setting
    else
      nil
    end
  end

  def initialize(archive_path, ignore_force)
    @archive_path = File.expand_path(archive_path)
    @ignore_force = ignore_force
    @replace_pattern = []
    load_settings
    set_attribute
    load_replace_pattern
  end

  #
  # 小説変換時の設定値読込
  #
  # 設定値の優先順位は
  # 1. narou setting コマンドで設定した force.*
  # 2. setting.ini
  # 3. DEFAULT_SETTINGS
  #
  def load_settings
    @setting = {}
    ini_path = File.join(@archive_path, INI_NAME)
    ini = Ini.load_file(ini_path) rescue Ini.load("")
    force_settings = {}
    unless @ignore_force
      # 設定値を強制的に上書きするデータの読込
      Inventory.load("local_setting", :local).each { |name, value|
        if name =~ /^force\.(.+)$/
          force_settings[$1] = value
        end
      }
    end
    DEFAULT_SETTINGS.each do |element|
      name, value, type = element[:name], element[:value], element[:type]
      if force_settings.include?(name)
        @setting[name] = force_settings[name]
      elsif ini["global"].include?(name) && type == Helper.type_of_value(ini["global"][name])
        @setting[name] = ini["global"][name]
      else
        @setting[name] = value
      end
    end
    # デフォルト設定以外を読み込む
    ini["global"].each do |key, value|
      unless @setting.include?(key)
        @setting[key] = value
      end
    end
  end

  #
  # 設定を保存
  #
  def save_settings
    ini = Ini.new
    ini.filename = File.join(@archive_path, INI_NAME)
    ini.object["global"].merge!(@setting)
    ini.save
  end

  #
  # 指定された設定の型チェック
  #
  def check_value_of_type(name, value)
    index = DEFAULT_SETTINGS.index { |v| v[:name] == name }
    return unless index
    default = DEFAULT_SETTINGS[index]
    if default && default[:type] != Helper.type_of_value(value)
      raise Helper::InvalidVariableType, default[:type]
    end
  end

  #
  # 設定データ用アクセサ定義
  #
  def set_attribute
    @setting.each_key do |key|
      instance_eval <<-EOS
        def #{key}
          @setting["#{key}"]
        end

        def #{key}=(value)
          check_value_of_type("#{key}", value)
          @setting["#{key}"] = value
        end
      EOS
    end
  end

  #
  # 配列風のアクセサ定義
  #
  def [](name)
    @setting[name]
  end

  def []=(name, value)
    check_value_of_type(name, value)
    @setting[name] = value
  end

  #
  # replace.txt による置換定義を読み込む
  #
  def load_replace_pattern
    @replace_pattern.clear
    replace_txt_path = File.join(@archive_path, REPLACE_NAME)
    if File.exist?(replace_txt_path)
      open(replace_txt_path, "r:BOM|UTF-8") do |fp|
        fp.each do |line|
          line.sub!(/[\r\n]+\z/, "")
          next if line[0] == ";"    # コメント記号
          pattern = line.split("\t", 2)
          if pattern.length == 2 && pattern[0]
            @replace_pattern << pattern
          end
        end
      end
    end
    @replace_pattern
  end

  #
  # replace.txt に設定を書き戻す
  #
  def save_replace_pattern
    replace_txt_path = File.join(@archive_path, REPLACE_NAME)
    buff = @replace_pattern.each_with_object("\t").map(&:join).join("\n")
    File.write(replace_txt_path, buff)
  end

  DEFAULT_SETTINGS = [
    # name: 変数名
    # type: 変数の型
    # value: 初期値
    # help: 説明(setting.ini に書き出される)
    {
      name: "enable_convert_num_to_kanji",
      type: :boolean,
      value: true,
      help: "数字の漢数字変換を有効に"
    },
    {
      name: "enable_kanji_num_with_units",
      type: :boolean,
      value: true,
      help: "漢数字変換した場合、千・万などに変換するか"
    },
    {
      name: "kanji_num_with_units_lower_digit_zero",
      type: :integer,
      value: 3,
      help: "〇(ゼロ)が最低この数字以上付いてないと千・万などをつける対象にしない"
    },
    {
      name: "enable_alphabet_force_zenkaku",
      type: :boolean,
      value: false,
      help: "アルファベットを強制的に全角にする。falseの場合英文は半角、それ以外は全角になる"
    },
    {
      name: "enable_half_indent_bracket",
      type: :boolean,
      value: true,
      help: "行頭かぎ括弧に二分アキを挿入する"
    },
    {
      name: "enable_auto_indent",
      type: :boolean,
      value: true,
      help: "自動行頭字下げ機能。行頭字下げが行われているかを判断し、適切に行頭字下げをする"
    },
    {
      name: "enable_auto_join_in_brackets",
      type: :boolean,
      value: true,
      help: "かぎ括弧内自動連結を有効に\n例)\n「～～～！\n　＊＊＊？」  → 「～～～！　＊＊＊？」"
    },
    {
      name: "enable_inspect_invalid_openclose_brackets",
      type: :boolean,
      value: false,
      help: "かぎ括弧内のとじ開きが正しくされているかどうか調査する"
    },
    {
      name: "enable_auto_join_line",
      type: :boolean,
      value: true,
      help: "行末が読点で終わっている部分を出来るだけ連結する"
    },
    {
      name: "enable_enchant_midashi",
      type: :boolean,
      value: true,
      help: "［＃改ページ］直後の行に中見出しを付与する（テキストファイルを直接変換する場合のみの設定）"
    },
    {
      name: "enable_author_comments",
      type: :boolean,
      value: true,
      help: "作者コメントを検出するか（テキストファイルを直接変換する場合のみの設定）"
    },
    {
      name: "enable_erase_introduction",
      type: :boolean,
      value: false,
      help: "前書きを削除するか"
    },
    {
      name: "enable_erase_postscript",
      type: :boolean,
      value: false,
      help: "後書きを削除するか"
    },
    {
      name: "enable_ruby",
      type: :boolean,
      value: true,
      help: "ルビ処理を有効に"
    },
    {
      name: "enable_illust",
      type: :boolean,
      value: true,
      help: "挿絵タグを有効にする（false なら削除）"
    },
    {
      name: "enable_transform_fraction",
      type: :boolean,
      value: false,
      help: "○／×表記を×分の○表記に変換する。日付表記(10/23)と誤爆しやすいので注意"
    },
    {
      name: "enable_transform_date",
      type: :boolean,
      value: false,
      help: "日付表記(20yy/mm/dd)を任意の形式(date_formatで指定)に変換する"
    },
    {
      name: "date_format",
      type: :string,
      value: "%Y年%m月%d日",
      help: "書式は http://bit.ly/1m5e3w7 を参考"
    },
    {
      name: "enable_convert_horizontal_ellipsis",
      type: :boolean,
      value: true,
      help: "中黒(・)を並べて三点リーダーもどきにしているのを三点リーダーに変換する"
    },
    {
      name: "enable_convert_page_break",
      type: :boolean,
      value: false,
      help: "`to_page_break_threshold` で設定した個数以上連続する空行を改ページに変換する"
    },
    {
      name: "to_page_break_threshold",
      type: :integer,
      value: 10,
      help: "ここで設定した値が `enable_convert_page_break` に反映される"
    },
    {
      name: "enable_dakuten_font",
      type: :boolean,
      value: true,
      help: "濁点フォントを使用するか。false の場合は縦中横による擬似表現を使用する"
    },
    {
      name: "enable_display_end_of_book",
      type: :boolean,
      value: true,
      help: "小説の最後に本を読み終わった表示をするかどうか"
    },
    {
      name: "enable_add_date_to_title",
      type: :boolean,
      value: false,
      help: "変換後の小説のタイトルに更新日の日付を付加するかどうか"
    },
    {
      name: "title_date_format",
      type: :string,
      value: "(%-m/%-d)",
      help: "enable_add_date_to_title で付与する日付のフォーマット。書式は http://bit.ly/1m5e3w7 を参照"
    },
    {
      name: "title_date_align",
      type: :string,
      value: "right",
      help: "enable_add_date_to_title で付与する日付の位置。left か right"
    },
    {
      name: "enable_ruby_youon_to_big",
      type: :boolean,
      value: false,
      help: "ルビの拗音(ぁ、ぃ等)を商業書籍のように大きくするかどうか"
    },
    {
      name: "enable_pack_blank_line",
      type: :boolean,
      value: true,
      help: "縦書きで読みやすいように空行を減らすかどうか"
    },
  ]
end
