

/*
document.addEventListener('DOMContentLoaded', () => {

    var switchButton = document.getElementById('switchButton');

    switchButton


});
*/

document.addEventListener('DOMContentLoaded', () => {

  document.getElementById("switchButton").addEventListener("click", ToggleLog);

  chrome.storage.sync.get("LTsw", (items) => {
   if(items["LTsw"]) {
    document.getElementById('switchButton').checked = true;
   }
  });
});
/*
var LogFunction = function (info) {
  
  console.log(info.url);
}; 
*/
function ToggleLog() {

  var switchButton = document.getElementById('switchButton');

  if (switchButton.checked) {

    chrome.storage.sync.set({ "LTsw" : true });
    /*chrome.webRequest.onBeforeRequest.addListener(
      LogFunction,
      { urls: ["<all_urls>"] },
      ['requestBody']
    );*/



  } else {

    chrome.storage.sync.set({ "LTsw" : false });
    /*chrome.webRequest.onBeforeRequest.removeListener(
      LogFunction
    );*/

  }
}
