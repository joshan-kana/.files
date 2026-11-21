#!/usr/bin/env bash
gpu=null
cpu_temp=null
gpu_temp=null
for path in /sys/class/drm/card*/device/gpu_busy_percent /sys/class/drm/card*/device/gt_busy_percent; do
  [ -r "$path" ] || continue
  IFS= read -r value <"$path" || true
  if [[ $value =~ ^[0-9]+$ ]] && ((value <= 100)); then
    gpu="$value"
    break
  fi
done
for device in /sys/class/hwmon/hwmon*; do
  [ -r "$device/name" ] || continue
  IFS= read -r name <"$device/name" || true
  case "$name" in
  coretemp | k10temp | zenpower | cpu_thermal | soc_thermal | scmi_sensors) target=cpu ;;
  amdgpu | nouveau) target=gpu ;;
  *) continue ;;
  esac
  for path in "$device"/temp*_input; do
    [ -r "$path" ] || continue
    IFS= read -r value <"$path" || true
    if [[ $value =~ ^[0-9]+$ ]] && ((value <= 150000)); then
      if [ "$target" = cpu ]; then cpu_temp="$value"; else gpu_temp="$value"; fi
      break
    fi
  done
done
if [ "$cpu_temp" = null ]; then
  for device in /sys/class/thermal/thermal_zone*; do
    [ -r "$device/type" ] && [ -r "$device/temp" ] || continue
    IFS= read -r name <"$device/type" || true
    case "$name" in
    x86_pkg_temp | cpu-thermal | cpu_thermal | soc_thermal | soc-thermal)
      IFS= read -r value <"$device/temp" || true
      if [[ $value =~ ^[0-9]+$ ]] && ((value <= 150000)); then
        cpu_temp="$value"
        break
      fi
      ;;
    esac
  done
fi
printf '{"gpuPercent":%s,"cpuMilliC":%s,"gpuMilliC":%s}\n' "$gpu" "$cpu_temp" "$gpu_temp"
