// Load external links in a new tab
var links = document.body.getElementsByTagName("a");

for (var i = 0, linksLength = links.length; i < linksLength; i++) {
   if (links[i].hostname !== window.location.hostname) {
      links[i].target = '_blank';
   }
}
