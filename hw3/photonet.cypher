CREATE (u1:User {name: 'John'}), (u2:User {name: 'Mary'}), (u3:User {name: 'Adrian'}), (u4:User {name: 'Claire'}), (u5:User {name: 'Holly'})

CREATE (u1)-[:POSTED]->(p1:Photo {file: 'file_name1'}),
       (u4)-[:POSTED]->(p2:Photo {file: 'file_name2'}),
       (u2)-[:POSTED]->(p3:Photo {file: 'file_name3'}),
       (u1)-[:POSTED]->(p4:Photo {file: 'file_name4'}),
       (u3)-[:POSTED]->(p5:Photo {file: 'file_name5'}),
       (u4)-[:POSTED]->(p6:Photo {file: 'file_name6'}),
       (u4)-[:POSTED]->(p7:Photo {file: 'file_name7'}),
       (u2)-[:POSTED]->(p8:Photo {file: 'file_name8'})

CREATE (u2)-[:FOLLOWS]->(u1), (u3)-[:FOLLOWS]->(u1), (u4)-[:FOLLOWS]->(u1),
       (u1)-[:FOLLOWS]->(u2), (u3)-[:FOLLOWS]->(u2), (u2)-[:FOLLOWS]->(u3),
       (u4)-[:FOLLOWS]->(u3), (u1)-[:FOLLOWS]->(u4), (u5)-[:FOLLOWS]->(u3)

MATCH (u5:User {name:'Holly'}), (p3:Photo {file:'file_name3'}) 
CREATE (u5)-[:COMMENTED {text: 'Not bad'}]->(p3)

MATCH (u1:User {name:'John'}), (p3:Photo {file:'file_name3'}) 
CREATE (u1)-[:COMMENTED {text: 'Excellent'}]->(p3)

MATCH (u4:User {name:'Claire'}), (p2:Photo {file:'file_name2'})<-[:POSTED]-(u4)
MATCH (john:User {name:'John'}), (mary:User {name:'Mary'}), (adrian:User {name:'Adrian'})
CREATE (mary)-[:LIKES {dt: '01/26/2024'}]->(p1), (john)-[:LIKES {dt: '01/25/2024'}]->(p2)

