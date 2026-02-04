awk 'NR==FNR {gsub(/[{}" ]/,"",$0); split($0,a,":"); if(length(a)==2) map[a[1]]=a[2]; next} 
/<w / && /pos="N\.Prop\./ && match($0,/lemma="([^"]+)"/,m) && m[1] in map {
    sub(/WLSPH=[0-9.]+/, "WLSPH=" map[m[1]])
} 
{print}' pn.jsonl hachidaishu.xml > hachidaishu-patched.xml
