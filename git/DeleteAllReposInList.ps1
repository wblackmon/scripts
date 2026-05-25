$repos = @(
"LaunchToggle-R1"
"SharpEcho.CodeChallenge.Start"
)

foreach ($r in $repos) {
    gh repo delete "wblackmon/$r" --yes
}
