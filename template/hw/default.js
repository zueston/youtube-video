function hw(){
    var ts = Date.parse(new Date());

    var x = document.getElementsByTagName("a");
    for (var i = 0; i < x.length; i++) {
        dl = x[i];
        if (dl.href !== "" && dl.href.indexOf("?") == -1) {
            dl.href = dl.href + "?" + ts;
        }
    }
    
    var ua = navigator.userAgent.toLowerCase();
    
    var isWeixin = ua.indexOf('micromessenger') != -1;
    if (!isWeixin) {
        $("#ua").hide();
    }    
}
