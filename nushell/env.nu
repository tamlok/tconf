# Load Visual Studio 2022 (default: Enterprise, x64) environment vars into the current Nushell session.
def --env setvs [
    --edition: string = "Enterprise"  # "Enterprise" | "Professional" | "Community"
    --arch: string = "x64"            # "x64" | "x86"
] {
    # Build the batch path safely
    let root = ([$env.PROGRAMFILES "Microsoft Visual Studio" "2022" $edition] | path join)
    let bat = (if $arch == "x64" {
        [$root "VC" "Auxiliary" "Build" "vcvars64.bat"] | path join
    } else {
            [$root "VC" "Auxiliary" "Build" "vcvars32.bat"] | path join
        })

    if (not ($bat | path exists)) {
        print $"Error: Can't find VS env batch file at: ($bat)"
        print "Tip: Try --edition Community or Professional, or switch to VsDevCmd.bat (see below)."
        return
    }

    let temp_bat = ($nu.temp-path | path join $"vs-env-(random chars).bat")
    $'call "($bat)" && set' | save -f $temp_bat
    let dumped = (^cmd /c $temp_bat)
    rm $temp_bat

    # Parse KEY=VALUE lines; ignore pseudo vars that start with '='
    let rows = (
        $dumped
        | lines
        | where {|line| $line != "" and not ($line | str starts-with "=") }
        | parse -r '^(?P<key>[^=]+)=(?P<value>.*)$'
    )

    let new_path = ($rows | where key == "PATH" or key == "Path" | get value | first)

    if ($new_path != null) {
        $env.PATH = ($new_path | split row (char esep))
        print $"VS2022 ($edition) PATH loaded for ($arch)"
    } else {
        print "Error: Could not find PATH in VS environment"
    }
}
