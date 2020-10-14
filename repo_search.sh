#!/bin/sh

no_links () {
  HEADER="Repo | Package | Version"
  REPOS=$(
    curl -s "https://repology.org/project/${1}/versions"|
    grep -A2 '<a href="/repository/'|
    sed -E 's| <a href.*$||;
    s|^[[:space:]]*||;
    s|<td class="text-center">||;
    s|<a href=".*">||;
    s|<span class="version.*">||;
    s~</(a|td|span)>.*$~~; /^--/d'|
    sed 'N;N;s/\n/ | /g'
  )
}

links() {
  HEADER="Repo | Package | Version | Link"
  REPOS=$(
    curl -s "https://repology.org/project/${1}/versions"|
    grep -A2 '<a href="/repository/' |
    sed -E 's| <a href.*$||;
    s|^[[:space:]]*<a href="/repository/.*">(.*)</a>.*|\1|;
    s~^[[:space:]]*<td class="text-center">.*<span.*<a href="(.*)">(.*)</a>.*~ \2 | \1~;
    s|^[[:space:]]*<td.*">||;
    s|</.*$||;
    /^--/d'|
    sed 'N;N;s/\n/ | /g'
  )
}

repos () {
  if [ "$MODE" = 1 ]; then
    no_links "$@"
  else
    links "$@"
  fi
  [ -z "$REPOS" ] && echo "Couldn't find $1 package." && exit
  [ -n "$2" ] && REPOS=$(echo "$REPOS" | grep -i "$2")
  [ -z "$REPOS" ] && echo "Couldn't find $1 package for $2." && exit
  echo "$HEADER"
  echo "$REPOS"
}

# choose between multiple and single entries
result () {
  RESULT=$(curl -s "https://repology.org/projects/?search=${1}&maintainer=&category=&inrepo=&notinrepo=&repos=&families=&repos_newest=&families_newest="|
  sed -En 's|^[[:space:]]*<a href="/project/.*/versions">([[:graph:]]*)</a>.*|\1|p')
  MAX=$(echo "$RESULT" | wc -l)
if [ -n "$RESULT" ] && [ "$MAX" -gt 1 ]; then
  packages
elif [ -n "$RESULT" ] && [ "$MAX" -eq 1 ]; then
  PACKAGE="$RESULT"
  repos "$PACKAGE"
else
  echo "No packages found." && exit 1
fi
}

# multiple entries
packages () {
  while true; do
  echo "Please type the package number or e to exit:"
  echo "$RESULT" | nl -w1 -s ")" 
  echo "e)exit"
  read -r SELECT
  case $SELECT in
    e) exit;;
    ''|*[!0-9]*) clear && echo "Type the number of the package you want to search for.";;
    *) if [ "$SELECT" -gt "$MAX" ]; then
        clear && echo "There are only $MAX options!"
      else
        PACKAGE=$(echo "$RESULT" | sed -n "${SELECT}"p)
        repos "$PACKAGE"
        break
      fi;;
  esac
done
}

# help message
get_help () {
  printf "repo_search: Check for availability for the given package using repology.org database.\n
Usage: repo_search [options] PACKAGE [distro]\n
Options:\n -s, --search PACKAGE\t\tPerforms ambiguous search.
\t\t\t\tThis is the default option.\n
 -l, --links PACKAGE\t\tAdds links to the ambiguous search.\n
 -p, --precise PACKAGE [repo]\tPerform a literal search for the given pacakge.
\t\t\t\tYou can also specify a repository (AUR, Ubuntu...).\n
 -d, --detailed PACKAGE [repo]\tAdd links to the literal search.\n
 -h, --help\t\t\tGet this help message.

Examples:
 repo_search youtube-dl\n repo_search -p youtube-dl
 repo_search -d youtube-dl Alpine"
}

# options
case "$1" in
  '') get_help;;
  -s|--search) shift && MODE=1 && result "$@";;
  -l|--links) shift && MODE=2 && result "$@";;
  -p|--precise) shift && MODE=1 && repos "$@";;
  -d|--detailed) shift && MODE=2 && repos "$@";;
  -h|--help) get_help;;
  *) MODE=1 && result "$@";;
esac
