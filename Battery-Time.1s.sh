#!/bin/zsh

# バッテリー情報の取得
battery_info=$(pmset -g batt)
battery_percent=$(echo "$battery_info" | grep -o '[0-9]\+%' | sed 's/%//')
power_source=$(echo "$battery_info" | grep -o 'AC Power')

# 容量情報
capacity_wh=52.6  # MacBook Air M2 のバッテリー容量 (仮定)

# 現在のバッテリーの充電量（％）を取得
current_capacity_percent=$battery_percent

# 前回の充電量（％）を保存するファイル
previous_capacity_file="/tmp/previous_capacity_percent.txt"

# 初回または前回のデータがない場合、現在の容量を保存して終了
if [ ! -f "$previous_capacity_file" ]; then
  echo "$current_capacity_percent" > "$previous_capacity_file"
  echo "$battery_percent% | color=gray"
  exit 0
fi

# 前回のバッテリー容量（％）を読み込み
previous_capacity_percent=$(cat "$previous_capacity_file")
echo "$current_capacity_percent" > "$previous_capacity_file"

# 消費・充電速度の推定
delta_capacity_percent=$((current_capacity_percent - previous_capacity_percent))
interval_minutes=1  # このスクリプトが実行される間隔（分）

# 消費・充電速度の推定、推定できない場合にはデフォルト値を使用
if [ "$delta_capacity_percent" -ne 0 ]; then
  # 推定が可能な場合の消費・充電速度（W）単位で計算
  power_rate=$(awk "BEGIN {print ($delta_capacity_percent * $capacity_wh / 100) * 60 / $interval_minutes}")
else
  # デフォルト値を使用
  if [ -z "$power_source" ]; then
    discharge_rate=7      # 放電時の仮定消費電力 7W
  else
    charge_rate=20        # 充電時の仮定充電速度 20W
  fi
fi

# 推定された `power_rate` に応じて消費・充電速度を設定
if [ "$delta_capacity_percent" -ne 0 ]; then
  if [ -z "$power_source" ]; then
    discharge_rate=${power_rate#-}  # 放電速度（絶対値に変換）
  else
    charge_rate=${power_rate#-}     # 充電速度（絶対値に変換）
  fi
fi

# バッテリーの状態を判定
if [ -z "$power_source" ]; then
  # 放電中の場合
  remaining_time_minutes=$(awk "BEGIN {print int($battery_percent * $capacity_wh * 60 / $discharge_rate / 100)}")
  hours=$((remaining_time_minutes / 60))
  minutes=$((remaining_time_minutes % 60))

  # 放電中の残り時間を白色で表示
  echo "$battery_percent% ${hours}時間 ${minutes}分 | color=white"
else
  # 充電中の場合
  remaining_charge_needed=$(awk "BEGIN {print (100 - $battery_percent) * $capacity_wh / 100}")
  remaining_time_minutes=$(awk "BEGIN {print int($remaining_charge_needed * 60 / $charge_rate)}")
  hours=$((remaining_time_minutes / 60))
  minutes=$((remaining_time_minutes % 60))

  # 充電完了までの残り時間をオレンジ色で表示
  echo "$battery_percent% ${hours}時間 ${minutes}分 | color=orange"
fi

