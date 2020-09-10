for ($i = 0; $i -lt 10; $i++) {
    New-Item -Path ".\$i" -ItemType Directory -Name $i

    for ($j = 0; $j -lt 10; $j++) {
        New-Item -Path ".\$i\$j" -ItemType Directory -Name $j

        for ($k = 0; $k -lt 10; $k++) {
            New-Item -Path ".\$i\$j\$k" -ItemType Directory -Name $k
    
            for ($l = 0; $l -lt 10; $l++) {
                New-Item -Path ".\$i\$j\$k\$l" -ItemType Directory -Name $l
        
                for ($m = 0; $m -lt 10; $m++) {
                    New-Item -Path ".\$i\$j\$k\$l\$m" -ItemType Directory -Name $m
            
                    for ($n = 0; $n -lt 10; $n++) {
                        New-Item -Path ".\$i\$j\$k\$l\$m\$n" -ItemType Directory -Name $n
                        
                    }            
                }        
            }    
        }
    }
}