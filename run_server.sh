cd server
while :
    do
        fpc @fpc.cfg lib/main.pas
        sleep 0.25
        lib/main
done
cd ../