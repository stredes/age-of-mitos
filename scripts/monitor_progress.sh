#!/bin/bash
# Monitor de progreso para Age of Mitos multi-PC
# Ejecutar en Arch para monitorear Kali y MINT

PROJECT_DIR="$HOME/Workspace/age-of-mitos"
LOG_FILE="$PROJECT_DIR/docs/PROGRESS_LOG.md"

echo "# Progress Log - Age of Mitos" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

while true; do
    echo "=== $(date) ===" >> "$LOG_FILE"
    
    # Check Kali
    echo "### KALI" >> "$LOG_FILE"
    ssh stredes@192.168.1.100 "cd ~/Workspace/age-of-mitos && git status --short && echo '---' && find tests/ -name '*.gd' 2>/dev/null | wc -l && echo ' test files'" >> "$LOG_FILE" 2>/dev/null
    
    # Check Mint
    echo "### MINT" >> "$LOG_FILE"
    ssh stredesmers@192.168.1.90 "cd ~/Workspace/age-of-mitos && git status --short && echo '---' && find tests/ -name '*.gd' 2>/dev/null | wc -l && echo ' test files'" >> "$LOG_FILE" 2>/dev/null
    
    # Check Arch
    echo "### ARCH" >> "$LOG_FILE"
    cd "$PROJECT_DIR" && git status --short >> "$LOG_FILE" 2>/dev/null
    
    echo "" >> "$LOG_FILE"
    
    sleep 60
done
