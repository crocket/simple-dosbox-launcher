#!/usr/bin/env janet
(import sh)
(import argparse)

(def- help-text
  ``
  Launch an executable in an archive file with dosbox.

  Application data is stored in $XDG_DATA_HOME/simple-dosbox-launcher/instance

  Runtime data is managed in $XDG_RUNTIME_DIR/simple-dosbox-launcher/instance

  Instance-specific dosbox configuration is found at
  $XDG_CONFIG_HOME/simple-dosbox-launcher/instance.conf

  Thus, setting instance option is important.
  ``)

(defn- print-info
  [{"conf" conf "instance" instance "file" file "exe" exe}
   inst-conf lower upper merged]
  (printf "instance-specific dosbox configuration for %s:\n%s"
          instance inst-conf)
  (when conf
    (printf "\nAdditional configuration:\n%s" conf))
  (printf "\nUser data for %s:\n%s" instance upper)
  (printf "\n%s\nwill be extracted onto\n%s" file lower)
  (printf "\n%s\nwill be laid on top of\n%s\nat %s"
          upper lower merged)
  (printf "\n%s/%s will be executed." merged exe)
  (print))

(defn- cleanup
  [verbose merged runtime-dir]
  (when verbose
    (print "\nCleaning up..."))
  (sh/run fusermount -u ,merged)
  (sh/run rm -rf ,runtime-dir))

(defn- launch-dosbox
  [{"file" file "conf" conf "exe" exe} inst-conf lower upper merged]
  (sh/$ atool -q -X ,lower ,file)
  (sh/$ unionfs -o "cow,hide_meta_files"
        (string/format "%s=RW:%s=RO" upper lower)
        ,merged)
  (sh/$ dosbox -exit -userconf -conf ,inst-conf
        ;(if conf
           ~[-conf ,conf]
           [])
        (string merged "/" exe)))

(defn- parse-opts
  []
  (argparse/argparse
    help-text
    "conf" {:kind :option
            :short "c"
            :help "Path to additional dosbox config file."}
    "file" {:kind :option
            :short "f"
            :required true
            :help "archive file that contains dosbox program."}
    "instance" {:kind :option
                :short "i"
                :required true
                :help "Instance name"}
    "exe" {:kind :option
           :required true
           :short "e"
           :help "Relative path to executable in archive file"}
    "verbose" {:kind :flag
               :short "v"
               :help "Verbose output"}))

(defn main
  [&]
  (when-let [opts (parse-opts)
             {"instance" instance "verbose" verbose} opts]
    (if-let [home (os/getenv "HOME")]
      (if-let [xdg-runtime-dir (os/getenv "XDG_RUNTIME_DIR")]
        (let [xdg-conf-dir (os/getenv "XDG_CONFIG_HOME"
                                      (string home "/.config"))
              xdg-data-dir (os/getenv "XDG_DATA_HOME"
                                      (string home "/.local/share"))
              conf-dir (string xdg-conf-dir "/simple-dosbox-launcher")
              inst-conf (string conf-dir "/" instance ".conf")
              runtime-dir (string xdg-runtime-dir "/simple-dosbox-launcher/"
                                  instance)
              lower (string runtime-dir "/lower")
              merged (string runtime-dir "/merged")
              upper (string xdg-data-dir "/simple-dosbox-launcher/"
                                instance)]
          (when verbose
            (print-info opts inst-conf lower upper merged))
          (loop [dir :in [lower upper merged]]
            (when (not (os/stat dir))
              (sh/$ mkdir -p ,dir)))
          (defer (cleanup verbose merged runtime-dir)
            (launch-dosbox opts inst-conf lower upper merged)))
        (error "Failed to get $XDG_RUNTIME_DIR"))
      (error "Failed to get $HOME"))))
