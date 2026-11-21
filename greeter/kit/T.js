.pragma library
// Zweisprachig ohne Übersetzungskatalog: SDDM hat keinen, und alle Texte sind kurz.
const de = Qt.locale().name.indexOf("de") === 0;
function t(deText, enText) { return de ? deText : enText; }
