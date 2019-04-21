ServerUrl = 'http://localhost:8580';

function LogUrl(url) {

    try {
        var req = new XMLHttpRequest();
        req.open("POST", ServerUrl + "/addurl", false);
        req.setRequestHeader("Accept", "application/json");
        req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
        req.send(JSON.stringify({ url: url }));
        if (req.readyState == 4) {
            if (req.status == 200) {
                console.log(JSON.parse(req.responseText).success);
            } else {

                if (req.status == 500) {
                    console.log(JSON.parse(req.responseText).error);
                } else {
                    console.log(req.responseText);
                }
            }
        }
    }
    catch (e) {
        console.log(e.message);
    }
}




var LogFunction = function (info) {



    if (info.url != ServerUrl + "/addurl") {

        console.log(info.url);

        LogUrl(info.url);
    }
    /*chrome.storage.sync.get("LTsw", (items) => {

        if (items["LTsw"]) {

            console.log(info.url);

        } else {

            //console.log("Stop");
        }

    });*/
};


chrome.storage.sync.get("LTsw", (items) => {

    if (items["LTsw"]) {

        chrome.webRequest.onBeforeRequest.addListener(
            LogFunction,
            { urls: ["<all_urls>"] }
        );

    } else {

        //console.log("Stop");
    }

});

/*chrome.webRequest.onBeforeRequest.addListener(
    LogFunction,
    { urls: ["<all_urls>"] }
);*/

chrome.storage.onChanged.addListener((changes, namespace) => {

    if (changes["LTsw"] !== "undefined") {

        var storageChange = changes["LTsw"];

        if (storageChange.newValue) {

            //console.log(storageChange);

            chrome.webRequest.onBeforeRequest.addListener(
                LogFunction,
                { urls: ["<all_urls>"] }
            );
        } else {

            //console.log(storageChange);

            chrome.webRequest.onBeforeRequest.removeListener(
                LogFunction
            );

        }
    }
});

/*
setTimeout(function() {

    
    chrome.storage.sync.get("sw", (items) => {
        
       if(items["sw"]) {

            chrome.webRequest.onBeforeRequest.addListener(
                LogFunction,
                { urls: ["<all_urls>"] },
                ['requestBody']
            );

        } else {

            chrome.webRequest.onBeforeRequest.removeListener(
                LogFunction
            );
        }

      });

}, 1000)
*/