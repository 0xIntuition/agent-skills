# Common Workflows

Follow these multi-step recipes for common Intuition operations. Each assumes you've already run the Session Setup Pattern from `reading-state.md` and have `atomCost`, `tripleCost`, and `curveId` cached.

## 1. Create an Atom and Deposit

```
1. calculateAtomId(stringToHex("Ethereum")) -> check if exists with isTermCreated()
2. createAtoms([stringToHex("Ethereum")], [0])  value=atomCost
   -> returns [atomId]
3. previewDeposit(atomId, curveId, depositAmount) -> (expectedShares, assetsAfterFees)
4. deposit(receiver, atomId, curveId, expectedShares * 95n / 100n)  value=depositAmount
```

## 2. Create a Triple (Subject-Predicate-Object)

```
1. Ensure all three atoms exist (create if needed)
2. Get atom IDs: calculateAtomId() for each
3. createTriples([subjectId], [predicateId], [objectId], [0])  value=tripleCost
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

A common pattern using the known `is` predicate:

```
1. Create or look up subject atom: calculateAtomId(stringToHex("MyAgent"))
2. Use known "is" predicate: 0xb0681668ca193e8608b43adea19fecbbe0828ef5afc941cef257d30a20564ef1
3. Use known "AI Agent" object: 0x4990eef19ea1d9b893c1802af9e2ec37fbc1ae138868959ebc23c98b1fc9565e
4. getTripleCost() -> tripleCost
5. createTriples([subjectId], [isPredicateId], [aiAgentObjectId], [0])  value=tripleCost
```

## 7. Batch Create Atoms and Triple

Create multiple atoms and link them in one flow:

```
1. createAtoms([stringToHex("Alice"), stringToHex("trusts"), stringToHex("Bob")], [0, 0, 0])
   value = atomCost * 3
   -> returns [aliceId, trustsId, bobId]
2. createTriples([aliceId], [trustsId], [bobId], [0])  value=tripleCost
   -> returns [tripleId]
```
