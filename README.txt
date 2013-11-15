
■ schema2excel: データベース定義書自動生成ツール

schema2excel はデータベースから定義情報を抽出し、
DB 定義書っぽいものを生成するツールです。

MySQL, PostgreSQL, SQL Server に対応しています。
※ Oracle は必要になったら考えます。 
※ MySQL 以外では細かい動作確認を不足しています。
   必ず出力結果を目視で確認して下さい。

利用する際には以下のツールが必要です。

・Ruby 1.8.x
  ・http://rubyforge.org/projects/rubyinstaller/ がおすすめ
  ・1.8.6-26 では rubygems が動作しないので、1.8.x 系の最新版を使うこと
  ・1.9.x 系では動作しないようです
・DB ドライバ
  ・以下のコマンドでインストールされる
      gem install -r dbi
      gem install -r dbd-mysql
      gem install -r dbd-pg
      gem install -r mysql
  ・dll ディレクトリにあるファイル群を ruby\bin ディレクトリにコピーする
    ・Windows 版 MySQL Essential 5.x から抽出したもの
    ・Windows 版 PostgreSQL 8.4.x から抽出したもの
・Graphviz モジュール
  ・以下のコマンドでインストールされる
      gem install -r ruby-graphviz
・MS Excel
  ・Excel 2007 の場合は別途 OWC コンポーネントの入手が必要
  ・http://www.microsoft.com/downloads/details.aspx?FamilyID=7287252C-402E-4F72-97A5-E0FD290D4B76&displaylang=ja

■ 使い方

config.yaml を適当に編集した後、コマンドプロンプトから以下を実行して下さい。

% ruby schema2excel.rb output.xml

出力された output.xml がデータベース定義書です。


■ 仕組み

DBMS のテーブルコメント、カラムコメントを利用して定義を抽出しています。
そのため、テーブル定義にコメントを含める必要があります。

例 (MySQL):
  CREATE TABLE sample (
    id int(11) NOT NULL auto_increment COMMENT 'プライマリキー',
    body text NOT NULL COMMENT '本文',
    PRIMARY KEY (id)
  ) COMMENT 'サンプルテーブル';

例 (PostgreSQL):
  COMMENT ON TABLE sample IS 'サンプルテーブル';
  COMMENT ON COLUMN sample.id IS 'プライマリキー';

