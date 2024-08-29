readonly LOG_FILE="LOG/$(date '+%Y-%m-%d_%Hh-%Mm-%Ss').log"
./script_ok.sh | tee -a $LOG_FILE