# ANYToken stake
ANYToken stake smart contract

## install @openzeppelin/contracts

```shell
npm install
```

## modify

1. edit solidity source in `internal` directory
2. flatten solidity source in `internal` directory to `contracts` directory

```shell
truffle-flattener internal/FoodToken.sol | sed '/SPDX-License-Identifier:/d' | sed 1i'// SPDX-License-Identifier: MIT' > contracts/FoodToken.sol
truffle-flattener internal/MasterChef.sol | sed '/SPDX-License-Identifier:/d' | sed 1i'// SPDX-License-Identifier: MIT' > contracts/MasterChef.sol
```

## compile

```shell
truffle compile
```

## deploy

```shell
truffle migrate
```

## bytecode

use remix: <https://remix.ethereum.org/#optimize=true&evmVersion=null&version=soljson-v0.5.4+commit.9549d8ff.js&runs=200>
