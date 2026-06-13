// Neo4j Aura load script — run after `:auto USING PERIODIC COMMIT` style imports
// Place the CSVs in the import folder (or use Aura's Data Importer).
CREATE CONSTRAINT IF NOT EXISTS FOR (p:Person)  REQUIRE p.cnic IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (c:Company) REQUIRE c.ntn  IS UNIQUE;

LOAD CSV WITH HEADERS FROM 'file:///persons.csv' AS r
CREATE (:Person {cnic:r.cnic, name:r.name, district:r.district,
  declared_income:toFloat(r.declared_income), bank_balance:toFloat(r.bank_balance),
  vehicle_value:toFloat(r.vehicle_value), property_value:toFloat(r.property_value)});
LOAD CSV WITH HEADERS FROM 'file:///companies.csv' AS r
CREATE (:Company {ntn:r.ntn, name:r.name, business:r.business});
LOAD CSV WITH HEADERS FROM 'file:///vehicles.csv' AS r
CREATE (:Vehicle {reg:r.reg, make:r.make, model:r.model, value:toFloat(r.value)});
LOAD CSV WITH HEADERS FROM 'file:///properties.csv' AS r
CREATE (:Property {pid:r.pid, type:r.type, market_value:toFloat(r.market_value)});

// Relationships (match the unified edges.csv; route by src_type/dst_type/rel)
LOAD CSV WITH HEADERS FROM 'file:///edges.csv' AS r
CALL apoc.do.case([
  r.rel='OWNS' AND r.src_type='Person',  'MATCH (a:Person{cnic:$s}),(b) WHERE b.reg=$d OR b.pid=$d MERGE (a)-[:OWNS]->(b)',
  r.rel='DIRECTOR_OF', 'MATCH (a:Person{cnic:$s}),(c:Company{ntn:$d}) MERGE (a)-[:DIRECTOR_OF]->(c)',
  r.rel='FAMILY_OF',   'MATCH (a:Person{cnic:$s}),(b:Person{cnic:$d}) MERGE (a)-[:FAMILY_OF]->(b)'
], '', {s:r.src, d:r.dst}) YIELD value RETURN count(*);
