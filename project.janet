(declare-project
  :name "simple-dosbox-launcher"
  :description "Launch an executable in an archive file with dosbox"
  :dependencies ["https://github.com/andrewchambers/janet-sh.git"
                 "https://github.com/janet-lang/argparse.git"])

(declare-executable
  :name "simple-dosbox-launcher"
  :entry "main.janet"
  :install true)
