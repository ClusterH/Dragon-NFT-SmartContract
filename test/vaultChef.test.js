// const { expect } = require("chai");
// const { ethers } = require("hardhat");
// const { BigNumber } = ethers;
// const {
//   getBigNumber,
//   QUICK_SWAP,
//   WETH,
//   createPair,
//   createPairETH,
//   advanceBlock,
//   advanceTimeStamp,
// } = require("../scripts/shared");

// const MASTER_CHEF_DGNG_PER_BLOCK = getBigNumber(5, 16); // 0.05 dgng per block

// describe("Vault", function () {
//   before(async function () {
//     this.VaultChef = await ethers.getContractFactory("VaultChef");
//     this.MasterChef = await ethers.getContractFactory("MasterChef");
//     this.DragonUtility = await ethers.getContractFactory("DragonUtility");
//     this.MockDGNG = await ethers.getContractFactory("MockDCAU");
//     this.MockERC20 = await ethers.getContractFactory("MockERC20");
//     this.StrategyMasterChef = await ethers.getContractFactory(
//       "StrategyMasterChef"
//     );
//     this.StrategyMasterChefLP = await ethers.getContractFactory(
//       "StrategyMasterChefLP"
//     );

//     this.signers = await ethers.getSigners();
//     this.dev = this.signers[0];
//     this.bob = this.signers[1];
//     this.devWallet = this.signers[2];
//     this.withdrawFeeAddress = this.signers[3];
//     this.feeAddress = this.signers[4];
//   });

//   beforeEach(async function () {
//     this.vaultChef = await this.VaultChef.deploy();
//     this.dgng = await this.MockDGNG.deploy(this.dev.address);
//     this.usdc = await this.MockERC20.deploy(
//       "Mock USDC",
//       "MockUSDC",
//       getBigNumber(10000000000)
//     );

//     this.dragonUtility = await this.DragonUtility.deploy(
//       this.devWallet.address,
//       this.usdc.address
//     );
//     this.masterChef = await this.MasterChef.deploy(
//       this.dgng.address,
//       this.dragonUtility.address,
//       this.bob.address,
//       0,
//       MASTER_CHEF_DGNG_PER_BLOCK, // 0.05 DGNG
//       this.devWallet.address
//     );
//     await this.dgng.transferOwnership(this.masterChef.address);

//     /** Basic actions */
//     // create DGNG_WMATIC pair
//     this.DGNG_WMATIC = await createPairETH(
//       QUICK_SWAP.ROUTER,
//       QUICK_SWAP.FACTORY,
//       this.dgng.address,
//       getBigNumber(10000),
//       getBigNumber(50),
//       this.dev.address,
//       this.dev
//     );

//     // const dgngWmatic = await this.MockERC20.attatch(this.DGNG_WMATIC);
//     // const currentBal = await dgngWmatic.balanceOf(this.dev);
//   });

//   describe("StrategyMasterChef", function () {
//     beforeEach(async function () {
//       /** Add DGNG to MasterChef */
//       await (
//         await this.masterChef.add(50 * 100, this.dgng.address, 0, false)
//       ).wait(); // poolID: 0

//       this.dgngPoolId = 0;
//       this.strategyMasterChefDGNG = await this.StrategyMasterChef.deploy(
//         [
//           this.dgng.address,
//           this.withdrawFeeAddress.address,
//           this.feeAddress.address,
//         ],
//         this.vaultChef.address,
//         this.masterChef.address,
//         QUICK_SWAP.ROUTER,
//         this.dgngPoolId,
//         this.dgng.address,
//         this.dgng.address,
//         [
//           this.dgng.address,
//           WETH, // this is WMATIC
//         ]
//       );
//     });

//     it("Vault Add pool", async function () {
//       await this.vaultChef.addPool(this.strategyMasterChefDGNG.address);
//       expect(await this.vaultChef.poolLength()).to.be.equal(1);
//     });

//     it("Vault Deposit", async function () {
//       await this.vaultChef.addPool(this.strategyMasterChefDGNG.address);
//       const poolInfo = await this.vaultChef.poolInfo(this.dgngPoolId);
//       await this.dgng.approve(this.vaultChef.address, getBigNumber(1000000000));

//       const testAmount = 200;
//       await this.vaultChef.deposit(0, getBigNumber(testAmount));

//       const userInfo = await this.vaultChef.userInfo(
//         this.dgngPoolId,
//         this.dev.address
//       );

//       expect(userInfo).to.be.equal(getBigNumber(testAmount));
//     });

//     it("Vault withdraw", async function () {
//       await this.vaultChef.addPool(this.strategyMasterChefDGNG.address);
//       await this.dgng.approve(this.vaultChef.address, getBigNumber(1000000000));

//       const testDepositAmount = 200;
//       const testWithdrawAmount = 50;
//       await this.vaultChef.deposit(
//         this.dgngPoolId,
//         getBigNumber(testDepositAmount)
//       );

//       const userBalanceBefore = await this.dgng.balanceOf(this.dev.address);
//       const userInfoBefore = await this.vaultChef.userInfo(
//         this.dgngPoolId,
//         this.dev.address
//       );

//       await this.vaultChef.withdraw(
//         this.dgngPoolId,
//         getBigNumber(testWithdrawAmount)
//       );

//       const userBalanceAfter = await this.dgng.balanceOf(this.dev.address);
//       const userInfoAfter = await this.vaultChef.userInfo(
//         this.dgngPoolId,
//         this.dev.address
//       );

//       expect(userBalanceAfter).to.be.equal(
//         userBalanceBefore.add(getBigNumber(testWithdrawAmount)).sub(
//           getBigNumber(10) //withdraw fee 10% calc
//             .mul(getBigNumber(testWithdrawAmount))
//             .div(getBigNumber(100))
//         )
//       );
//       expect(userInfoAfter).to.be.equal(
//         userInfoBefore.sub(getBigNumber(testWithdrawAmount))
//       );
//     });

//     it("Vault earn", async function () {
//       await this.vaultChef.addPool(this.strategyMasterChefDGNG.address);
//       await this.dgng.approve(this.vaultChef.address, getBigNumber(1000000000));

//       const testDepositAmount = 200;
//       const testWithdrawAmount = 50;
//       await this.vaultChef.deposit(
//         this.dgngPoolId,
//         getBigNumber(testDepositAmount)
//       );

//       await advanceBlock();
//       await advanceTimeStamp(10);

//       await this.vaultChef.withdraw(
//         this.dgngPoolId,
//         getBigNumber(testWithdrawAmount)
//       );

//       const earnedAmountBefore = await this.dgng.balanceOf(
//         this.strategyMasterChefDGNG.address
//       );

//       expect(earnedAmountBefore).to.not.equal(0);
//       await this.strategyMasterChefDGNG.earn();

//       const earnedAmountAfter = await this.dgng.balanceOf(
//         this.strategyMasterChefDGNG.address
//       );
//       expect(earnedAmountAfter).to.be.equal(0);
//     });
//   });

//   describe("StrategyMasterChefLP", function () {
//     beforeEach(async function () {
//       await (
//         await this.masterChef.add(100 * 100, this.DGNG_WMATIC, 0, false)
//       ).wait(); // poolID: 0
//       this.dgngMaticPoolId = 0;
//       this.strategyMasterChefLPDGNG_WMATIC =
//         await this.StrategyMasterChefLP.deploy(
//           [
//             this.dgng.address,
//             this.withdrawFeeAddress.address,
//             this.feeAddress.address,
//           ],
//           this.vaultChef.address,
//           this.masterChef.address,
//           QUICK_SWAP.ROUTER,
//           this.dgngMaticPoolId,
//           this.DGNG_WMATIC, // the token which we want to put in pool
//           this.dgng.address,
//           [
//             this.dgng.address,
//             WETH, // this is WMATIC
//           ],
//           [this.dgng.address, this.dgng.address],
//           [this.dgng.address, this.dgng.address],
//           [this.dgng.address, WETH]
//         );
//       this.dgngWmatic = await this.MockERC20.attach(this.DGNG_WMATIC);
//     });

//     it("Vault LP Deposit", async function () {
//       await this.vaultChef.addPool(
//         this.strategyMasterChefLPDGNG_WMATIC.address
//       );
//       const currentBal = await this.dgngWmatic.balanceOf(this.dev.address);
//       await this.dgngWmatic.approve(
//         this.vaultChef.address,
//         getBigNumber(1000000000)
//       );

//       // // 0.1 % of current balance
//       const testAmount = getBigNumber(1)
//         .mul(currentBal)
//         .div(getBigNumber(1000));
//       await this.vaultChef.deposit(this.dgngMaticPoolId, testAmount);
//       const userInfo = await this.vaultChef.userInfo(
//         this.dgngMaticPoolId,
//         this.dev.address
//       );
//       expect(userInfo).to.be.equal(testAmount);
//     });

//     it("Vault withdraw", async function () {
//       await this.vaultChef.addPool(
//         this.strategyMasterChefLPDGNG_WMATIC.address
//       );
//       await this.dgngWmatic.approve(
//         this.vaultChef.address,
//         getBigNumber(1000000000)
//       );
//       const currentBal = await this.dgngWmatic.balanceOf(this.dev.address);

//       // // 0.1 % of current balance
//       const testAmount = getBigNumber(1)
//         .mul(currentBal)
//         .div(getBigNumber(1000));
//       await this.vaultChef.deposit(this.dgngMaticPoolId, testAmount);
//       const userBalanceBefore = await this.dgngWmatic.balanceOf(
//         this.dev.address
//       );
//       const userInfoBefore = await this.vaultChef.userInfo(
//         this.dgngMaticPoolId,
//         this.dev.address
//       );
//       await this.vaultChef.withdraw(this.dgngMaticPoolId, testAmount);
//       const userBalanceAfter = await this.dgngWmatic.balanceOf(
//         this.dev.address
//       );
//       const userInfoAfter = await this.vaultChef.userInfo(
//         this.dgngMaticPoolId,
//         this.dev.address
//       );
//       expect(userBalanceAfter).to.be.equal(
//         userBalanceBefore.add(testAmount).sub(
//           getBigNumber(10) //withdraw fee 10% calc
//             .mul(testAmount)
//             .div(getBigNumber(100))
//         )
//       );
//       expect(userInfoAfter).to.be.equal(userInfoBefore.sub(testAmount));
//     });
//   });
// });
