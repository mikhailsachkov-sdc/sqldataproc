MATCH (u:User {name: 'Holly'})-[c:COMMENTED]->(p:Photo {file: 'file_name3'})
SET c.text = 'Very Good';

MATCH (u:User {name: 'John'})-[r:FOLLOWS]->()
DELETE r;

MATCH (mary:User {name: 'Mary'})-[:FOLLOWS]->(other:User)-[:POSTED]->(p:Photo)
RETURN p;

MATCH (claire:User {name: 'Claire'})-[:POSTED]->(p:Photo)<-[:LIKES]-(u:User)
RETURN count(u) as LikeCount;

MATCH (holly:User {name: 'Holly'})-[:FOLLOWS]->(common:User)<-[:FOLLOWS]-(peer:User)-[:FOLLOWS]->(rec:User)
WHERE NOT (holly)-[:FOLLOWS]->(rec) AND rec <> holly
RETURN DISTINCT rec.name as RecommendedUser;

