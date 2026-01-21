#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
master_dir="${root_dir}/skills"
common_dir="${master_dir}/common"
dist_root_dir="${root_dir}/.dist"
package_script="${HOME}/.codex/skills/.system/skill-creator/scripts/package_skill.py"
venv_dir="${HOME}/.codex/tmp/skill-creator-venv"
python_bin="${venv_dir}/bin/python"
target_names=(codex claude)
target_paths=("${HOME}/.codex/skills" "${HOME}/.claude/skills")
copy_script="${root_dir}/scripts/copy-ios-dev-docs.sh"
ios_dev_docs_ready=false

target_index_for() {
  local name="$1"
  local i
  for i in "${!target_names[@]}"; do
    if [ "${target_names[$i]}" = "${name}" ]; then
      echo "${i}"
      return 0
    fi
  done
  return 1
}

usage() {
  cat <<'EOF'
Usage: deploy_skills.sh [--target <codex|claude|all>]

Options:
  --target  Limit deployment to a single target.
  -h, --help  Show this help.
EOF
}

selected_targets=()
add_target() {
  local name="$1"
  local existing
  if [ "${#selected_targets[@]}" -gt 0 ]; then
    for existing in "${selected_targets[@]}"; do
      if [ "${existing}" = "${name}" ]; then
        return
      fi
    done
  fi
  selected_targets+=("${name}")
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      shift
      if [ $# -eq 0 ]; then
        echo "Missing value for --target" >&2
        usage
        exit 1
      fi
      if [ "$1" = "all" ]; then
        for name in "${target_names[@]}"; do
          add_target "${name}"
        done
      else
        if ! target_index_for "$1" >/dev/null; then
          echo "Unknown target: $1" >&2
          usage
          exit 1
        fi
        add_target "$1"
      fi
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [ "${#selected_targets[@]}" -eq 0 ]; then
  for name in "${target_names[@]}"; do
    add_target "${name}"
  done
fi

if [ -x "${copy_script}" ]; then
  if "${copy_script}"; then
    ios_dev_docs_ready=true
  else
    echo "Skip ios-dev-docs: failed to copy AdditionalDocumentation." >&2
  fi
else
  echo "Skip ios-dev-docs: missing copy script at ${copy_script}." >&2
fi

if [ ! -d "${master_dir}" ]; then
  echo "Missing master skills dir: ${master_dir}" >&2
  exit 1
fi
if [ ! -d "${common_dir}" ]; then
  echo "Missing common skills dir: ${common_dir}" >&2
  exit 1
fi

if [ ! -f "${package_script}" ]; then
  echo "Missing package script: ${package_script}" >&2
  exit 1
fi

for name in "${selected_targets[@]}"; do
  target_index="$(target_index_for "${name}")"
  mkdir -p "${target_paths[${target_index}]}"
done

if [ ! -x "${python_bin}" ]; then
  mkdir -p "$(dirname "${venv_dir}")"
  python3 -m venv "${venv_dir}"
fi

if ! "${python_bin}" -c "import yaml" >/dev/null 2>&1; then
  "${python_bin}" -m pip install -q pyyaml
fi

mkdir -p "${dist_root_dir}"

for target in "${selected_targets[@]}"; do
  dist_removed=0
  dist_linked=0
  dist_stale=0
  removed=0
  count=0

  target_index="$(target_index_for "${target}")"
  target_dir="${target_paths[${target_index}]}"
  target_dist_dir="${dist_root_dir}/${target}"
  dist_link="${target_dir}/dist"

  if [[ "${ios_dev_docs_ready}" != "true" ]]; then
    ios_docs_link="${target_dir}/ios-dev-docs"
    if [ -L "${ios_docs_link}" ]; then
      rm "${ios_docs_link}"
      removed=$((removed + 1))
    fi
  fi

  mkdir -p "${target_dist_dir}"
  if [ -L "${dist_link}" ]; then
    link_target="$(readlink "${dist_link}")"
    if [ "${link_target}" = "${dist_root_dir}" ] || [ "${link_target}" = "${target_dist_dir}" ]; then
      rm "${dist_link}"
      dist_removed=$((dist_removed + 1))
    elif [ ! -e "${dist_link}" ]; then
      rm "${dist_link}"
      dist_removed=$((dist_removed + 1))
    fi
  fi
  if [ ! -d "${dist_link}" ]; then
    mkdir -p "${dist_link}"
  fi

  skill_names=()
  skill_paths=()

  add_skill() {
    local name="$1"
    local path="$2"
    local i
    for i in "${!skill_names[@]}"; do
      if [ "${skill_names[$i]}" = "${name}" ]; then
        skill_paths[$i]="${path}"
        return
      fi
    done
    skill_names+=("${name}")
    skill_paths+=("${path}")
  }

  for skill in "${common_dir}"/*; do
    [ -d "${skill}" ] || continue
    name="$(basename "${skill}")"
    if [[ "${name}" == .* ]]; then
      continue
    fi
    if [[ "${name}" == "ios-dev-docs" && "${ios_dev_docs_ready}" != "true" ]]; then
      continue
    fi
    add_skill "${name}" "${skill}"
  done

  target_master="${master_dir}/${target}"
  if [ -d "${target_master}" ]; then
    for skill in "${target_master}"/*; do
      [ -d "${skill}" ] || continue
      name="$(basename "${skill}")"
      if [[ "${name}" == .* ]]; then
        continue
      fi
      if [[ "${name}" == "ios-dev-docs" && "${ios_dev_docs_ready}" != "true" ]]; then
        continue
      fi
      add_skill "${name}" "${skill}"
    done
  fi

  for i in "${!skill_names[@]}"; do
    name="${skill_names[$i]}"
    skill="${skill_paths[$i]}"
    "${python_bin}" "${package_script}" "${skill}" "${target_dist_dir}"
    dest="${target_dir}/${name}"
    if [ -e "${dest}" ] && [ ! -L "${dest}" ]; then
      echo "Skip existing non-symlink: ${dest}"
    else
      ln -sfn "${skill}" "${dest}"
    fi
    count=$((count + 1))
  done

  skill_index="$(printf '%s\n' "${skill_names[@]}")"
  for pkg in "${target_dist_dir}"/*.skill; do
    [ -e "${pkg}" ] || continue
    name="$(basename "${pkg}" .skill)"
    if ! printf '%s\n' "${skill_index}" | grep -Fxq "${name}"; then
      rm "${pkg}"
    fi
  done

  dist_target="${target_dir}/dist"
  for pkg in "${target_dist_dir}"/*.skill; do
    [ -e "${pkg}" ] || continue
    dest="${dist_target}/$(basename "${pkg}")"
    if [ -e "${dest}" ] && [ ! -L "${dest}" ]; then
      echo "Skip existing non-symlink: ${dest}"
      continue
    fi
    ln -sfn "${pkg}" "${dest}"
    dist_linked=$((dist_linked + 1))
  done

  for dest in "${target_dir}"/*; do
    [ -L "${dest}" ] || continue
    link_target="$(readlink "${dest}")"
    if [[ "${link_target}" == "${master_dir}/"* ]] && [ ! -d "${link_target}" ]; then
      rm "${dest}"
      removed=$((removed + 1))
      continue
    fi
    if [[ "${link_target}" == "${master_dir}/${target}/"* ]] && [ ! -d "${link_target}" ]; then
      rm "${dest}"
      removed=$((removed + 1))
    fi
  done

  for dest in "${dist_target}"/*.skill; do
    [ -L "${dest}" ] || continue
    link_target="$(readlink "${dest}")"
    if [[ "${link_target}" == "${dist_root_dir}/"* ]] && [[ "${link_target}" != "${target_dist_dir}/"* ]]; then
      rm "${dest}"
      dist_stale=$((dist_stale + 1))
      continue
    fi
    if [[ "${link_target}" == "${target_dist_dir}/"* ]] && [ ! -f "${link_target}" ]; then
      rm "${dest}"
      dist_stale=$((dist_stale + 1))
    fi
  done

  echo "Target ${target}: linked ${count} skills (common + ${target})"
  if [ "${dist_removed}" -gt 0 ]; then
    echo "Removed ${dist_removed} dist link(s)"
  fi
  echo "Linked ${dist_linked} skill package(s) into dist"
  if [ "${dist_stale}" -gt 0 ]; then
    echo "Removed ${dist_stale} stale dist link(s)"
  fi
  if [ "${removed}" -gt 0 ]; then
    echo "Removed ${removed} stale links"
  fi
done
