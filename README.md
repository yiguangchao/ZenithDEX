# ZenithDEX Core & Periphery

![License](https://img.shields.io/badge/license-MIT-blue) ![Solidity](https://img.shields.io/badge/solidity-^0.8.20-lightgrey) ![Foundry](https://img.shields.io/badge/framework-Foundry-orange) ![Coverage](https://img.shields.io/badge/coverage-95%25-green)

**ZenithDEX** is a gas-optimized, modernized decentralized exchange (DEX) protocol based on the AMM (Automated Market Maker) model ($x \times y = k$). 

Built for the post-2025 Web3 ecosystem, it leverages **Solidity 0.8.20+**, **Foundry** for rigorous fuzz testing, and custom gas-optimized mathematics libraries.

## 🏗 Architecture

The protocol is designed with a separation of concerns pattern:

* **Core Layer (`src/core`):** * **Factory:** Deploys pairs using `CREATE2` for deterministic addresses.
    * **Pair:** Handles low-level liquidity minting/burning and swapping with checks-effects-interactions pattern protection.
    * **Security:** Implements "Minimum Liquidity Locking" (1000 wei) to prevent inflation attacks.
* **Periphery Layer (`src/periphery`):**
    * **Router:** Abstraction layer for user interactions (Add Liquidity / Swap).
    * **Library:** Pure gas-optimized math for path pricing and reserve calculation.

## 🚀 Key Features

* **Modern Solidity Stack:** Unlike older DEXs (Solidity 0.5.x), ZenithDEX utilizes Solidity 0.8.x's built-in overflow checks, removing the need for `SafeMath` and reducing gas costs.
* **Architectural Decoupling:** Strict separation between core logic and user-facing routing logic.
* **Flash Loan Compatible:** The `swap` function supports optimistic transfers, enabling flash swaps.
* **Create2 Deterministic Deployment:** Allows for off-chain pair address pre-computation.

## 🛠 Tech Stack & Tools

* **Language:** Solidity (`^0.8.20`)
* **Framework:** Foundry (Forge, Cast, Anvil)
* **Testing:** * Unit Tests (Logic verification)
    * Integration Tests (Mint -> Swap -> Burn flows)
* **Libraries:** Solmate (Gas-optimized ERC20), OpenZeppelin.

## 📦 Installation & Testing

**1. Clone the repository**
```bash
git clone [https://github.com/yiguangchao/ZenithDEX.git](https://github.com/yiguangchao/ZenithDEX.git)
cd ZenithDEX
```
**2. Install dependencies**
```bash
forge install
```
**3. Run Tests**
```bash
forge test -vv
```
**4. Deploy (Simulation)**
```bash
forge script script/DeployZenithDEX.s.sol:DeployZenithDEX
```

## 📜 Mathematical Model
The exchange relies on the constant product formula:
$$x \cdot y = k$$
Where $x$ and $y$ are the reserves of two tokens. Trades are executed such that $k$ remains constant (before fees). A 0.3% fee is applied to every trade and added to the reserves, increasing $k$ over time for liquidity providers.

## 👨‍💻 Author
**GuangchaoYi** *Senior Blockchain Engineer & Java Veteran*
*[LinkedIn Link]*

