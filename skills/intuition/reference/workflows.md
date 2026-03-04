# Common Workflows

Follow these multi-step recipes for common Intuition operations. Each assumes you've already run the Session Setup Pattern from `reading-state.md` and have `atomCost`, `tripleCost`, `curveId`, and `$GRAPHQL` cached.

**All atoms are pinned to IPFS** before creation (except CAIP-10 addresses). See `reference/schemas.md` for the full pin flow. The pseudocode below uses `pin(name)` as shorthand for "pin via `pinThing` → get `ipfs://` URI → `stringToHex(uri)`".

## 1. Create an Atom and Deposit

```
1. Pin entity to IPFS:
   pinThing({ name: "Ethereum", description: "Decentralized computing platform", url: "https://ethereum.org" })
   -> ipfsUri

2. Check existence:
   atomData = stringToHex(ipfsUri)
   calculateAtomId(atomData) -> atomId
   isTermCreated(atomId) -> if true, skip to step 4

3. Create atom:
   createAtoms([atomData], [atomCost])  value=atomCost
   -> returns [atomId]

4. Preview and deposit:
   previewDeposit(atomId, curveId, depositAmount) -> (expectedShares, assetsAfterFees)
   deposit(receiver, atomId, curveId, expectedShares * 95n / 100n)  value=depositAmount
```

## 2. Create a Triple (Subject-Predicate-Object)

```
1. Pin all three atoms to IPFS (see reference/schemas.md):
   pin subject -> subjectUri
   pin predicate -> predicateUri  (or look up existing — see workflow 6)
   pin object -> objectUri

2. Encode and check existence for each:
   subjectData = stringToHex(subjectUri)
   predicateData = stringToHex(predicateUri)
   objectData = stringToHex(objectUri)

3. Create any atoms that don't exist yet:
   createAtoms([subjectData, predicateData, objectData], [atomCost, atomCost, atomCost])
   value = atomCost * 3  (only for atoms that need creation)

4. Get atom IDs and create triple:
   calculateAtomId(subjectData) -> subjectId
   calculateAtomId(predicateData) -> predicateId
   calculateAtomId(objectData) -> objectId
   createTriples([subjectId], [predicateId], [objectId], [tripleCost])  value=tripleCost
   -> returns [tripleId]
```

## 3. Signal Agreement (Deposit into Triple)

```
1. Get tripleId (from creation or calculateTripleId())
2. previewDeposit(tripleId, curveId, amount) -> (shares, assetsAfterFees)
3. deposit(myAddress, tripleId, curveId, minShares)  value=amount
```

## 4. Signal Disagreement (Deposit into Counter-Triple)

```
1. getCounterIdFromTripleId(tripleId) -> counterTripleId
2. previewDeposit(counterTripleId, curveId, amount) -> (shares, assetsAfterFees)
3. deposit(myAddress, counterTripleId, curveId, minShares)  value=amount
```

## 5. Check Position and Exit

```
1. getShares(myAddress, termId, curveId) -> myShares
2. previewRedeem(termId, curveId, myShares) -> (assetsAfterFees, sharesUsed)
3. redeem(myAddress, termId, curveId, myShares, minAssets)  value=0
```

## 6. Create a "Subject is Object" Attestation

Uses the `FindPredicate` query (see SKILL.md → Finding predicate atoms) to look up canonical predicates by label instead of hardcoded IDs:

```
1. Pin subject atom to IPFS:
   pinThing({ name: "MyAgent", description: "Autonomous research agent" })
   -> subjectUri
   subjectData = stringToHex(subjectUri)

2. Find canonical "is" predicate via GraphQL:
   FindPredicate({ label: "is" })
   -> pick first non-TextObject result by usage count -> isPredicateId
   (If only TextObject exists, create a pinned replacement)

3. Find canonical "AI Agent" object via GraphQL:
   atoms(where: { label: { _eq: "AI Agent" }, type: { _neq: "TextObject" } })
   -> aiAgentObjectId
   (If not found, pin and create it)

4. Create subject atom if needed:
   calculateAtomId(subjectData) -> subjectId
   isTermCreated(subjectId) -> if false, createAtoms([subjectData], [atomCost])

5. Create triple:
   createTriples([subjectId], [isPredicateId], [aiAgentObjectId], [tripleCost])
   value=tripleCost
```

## 7. Batch Create Atoms and Triple

Pin each entity separately, then batch the atom creation:

```
1. Pin all entities to IPFS:
   pinPerson({ name: "Alice" }) -> aliceUri
   pinThing({ name: "trusts" }) -> trustsUri
   pinPerson({ name: "Bob" }) -> bobUri

2. Encode all URIs:
   aliceData = stringToHex(aliceUri)
   trustsData = stringToHex(trustsUri)
   bobData = stringToHex(bobUri)

3. Batch create atoms:
   createAtoms([aliceData, trustsData, bobData], [atomCost, atomCost, atomCost])
   value = atomCost * 3
   -> returns [aliceId, trustsId, bobId]

4. Create triple:
   createTriples([aliceId], [trustsId], [bobId], [tripleCost])
   value=tripleCost
   -> returns [tripleId]
```

Note: Pin sequentially (no batch pin mutation exists), then batch the on-chain creation. Preserve strict index mapping — see `reference/schemas.md` → Batch Pinning.
