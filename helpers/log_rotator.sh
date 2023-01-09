#!/bin/bash

# Скрипт обеспечивает ротацию (по факту обрезку) лог-файла,
# переданного скрипту в качестве аргумента.
# 
# Используется утилита tail, которая оставляет в файле только
# $(LINES_COUNT) число строк.
#
# Рандомизатор пригодится для того, чтобы заставить скрипт
# срабатывать не каждый раз, а только в PERCENTILE
# количестве выполнений из RANDOMMAX.
#
# Если рандомизатор не нужен (например, скрипт исполняется 
# каждый раз при добавлении в лог), то следует выставить
# переменную RANDOMIZE в 0. (Быстродействие)

LINES_COUNT=2000
RANDOMMAX=100
PERCENTILE=10
NEED_EXECUTE=0
RANDOMIZE=0

# Первый параметр скрипта не должен быть пустым
if [[ -n "$1" ]]; then
    # Если указано не использовать рандомизацию
    if [[ "$RANDOMIZE" == 0 ]]; then
        NEED_EXECUTE=1
    else
        # Рандомизация нужна
        if [[ $((RANDOM%"$RANDOMMAX")) -lt $PERCENTILE && -f "$1" ]]; then
            NEED_EXECUTE=1    
        fi
    fi
    # Обрезаем лог
    if [[ "$NEED_EXECUTE" == 1 ]]; then
        tail --lines=2000 --silent "$1" > "$1.cut"
        mv "$1.cut" "$1"
    fi
fi