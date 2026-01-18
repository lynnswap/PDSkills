#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
master_dir="${root_dir}/skills"
dist_dir="${root_dir}/dist"
package_script="${HOME}/.codex/skills/.system/skill-creator/scripts/package_skill.py"
venv_dir="${HOME}/.codex/tmp/skill-creator-venv"
python_bin="${venv_dir}/bin/python"
targets=(
  "${HOME}/.codex/skills"
  "${HOME}/.claude/skills"
)

if [ ! -d "${master_dir}" ]; then
  echo "Missing master skills dir: ${master_dir}" >&2
  exit 1
fi

if [ ! -f "${package_script}" ]; then
  echo "Missing package script: ${package_script}" >&2
  exit 1
fi

for target in "${targets[@]}"; do
  mkdir -p "${target}"
done

if [ ! -x "${python_bin}" ]; then
  mkdir -p "$(dirname "${venv_dir}")"
  python3 -m venv "${venv_dir}"
fi

if ! "${python_bin}" -c "import yaml" >/dev/null 2>&1; then
  "${python_bin}" -m pip install -q pyyaml
fi

mkdir -p "${dist_dir}"

dist_removed=0
for target in "${targets[@]}"; do
  dist_link="${target}/dist"
  if [ -L "${dist_link}" ]; then
    link_target="$(readlink "${dist_link}")"
    if [ "${link_target}" = "${dist_dir}" ]; then
      rm "${dist_link}"
      dist_removed=$((dist_removed + 1))
    fi
  fi
  if [ ! -d "${dist_link}" ]; then
    mkdir -p "${dist_link}"
  fi
done

skill_names=()
count=0
for skill in "${master_dir}"/*; do
  [ -d "${skill}" ] || continue
  name="$(basename "${skill}")"
  if [[ "${name}" == .* ]]; then
    continue
  fi
  skill_names+=("${name}")
  "${python_bin}" "${package_script}" "${skill}" "${dist_dir}"
  for target in "${targets[@]}"; do
    dest="${target}/${name}"
    if [ -e "${dest}" ] && [ ! -L "${dest}" ]; then
      echo "Skip existing non-symlink: ${dest}"
      continue
    fi
    ln -sfn "${skill}" "${dest}"
  done
  count=$((count + 1))
done

skill_index="$(printf '%s\n' "${skill_names[@]}")"
for pkg in "${dist_dir}"/*.skill; do
  [ -e "${pkg}" ] || continue
  name="$(basename "${pkg}" .skill)"
  if ! printf '%s\n' "${skill_index}" | grep -Fxq "${name}"; then
    rm "${pkg}"
  fi
done

dist_linked=0
for target in "${targets[@]}"; do
  dist_target="${target}/dist"
  for pkg in "${dist_dir}"/*.skill; do
    [ -e "${pkg}" ] || continue
    dest="${dist_target}/$(basename "${pkg}")"
    if [ -e "${dest}" ] && [ ! -L "${dest}" ]; then
      echo "Skip existing non-symlink: ${dest}"
      continue
    fi
    ln -sfn "${pkg}" "${dest}"
    dist_linked=$((dist_linked + 1))
  done
done

removed=0
for target in "${targets[@]}"; do
  for dest in "${target}"/*; do
    [ -L "${dest}" ] || continue
    link_target="$(readlink "${dest}")"
    if [[ "${link_target}" == "${master_dir}/"* ]] && [ ! -d "${link_target}" ]; then
      rm "${dest}"
      removed=$((removed + 1))
    fi
  done
done

dist_stale=0
for target in "${targets[@]}"; do
  dist_target="${target}/dist"
  for dest in "${dist_target}"/*.skill; do
    [ -L "${dest}" ] || continue
    link_target="$(readlink "${dest}")"
    if [[ "${link_target}" == "${dist_dir}/"* ]] && [ ! -f "${link_target}" ]; then
      rm "${dest}"
      dist_stale=$((dist_stale + 1))
    fi
  done
done

echo "Linked ${count} skills from ${master_dir}"
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
