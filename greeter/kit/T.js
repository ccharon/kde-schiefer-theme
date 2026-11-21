.pragma library
// German/English without a translation catalog: SDDM has none, and all texts are short.
const de = Qt.locale().name.indexOf("de") === 0;
function t(deText, enText) { return de ? deText : enText; }
