// Delete all the mappings for a specified concept source name (ie. 'local').

allConcepts=concept.getAllConcepts();
myMap=null;
for (conc in allConcepts) {
  mappings= conc.getConceptMappings();

 for (mapping in mappings) {
   if(mapping.getConceptReferenceTerm().getConceptSource().getName()== 'local') {
      myMap=mapping; 
      break; 
      }
   }
 mappings.remove(myMap);
}
