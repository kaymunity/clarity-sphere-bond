import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create a new bond between two partners",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const partner = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'create-bond', [
        types.principal(partner.address)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk().expectUint(1);
    
    let bondCheck = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'get-bond', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    let bond = bondCheck.receipts[0].result.expectOk().expectSome();
    assertEquals(bond['partner1'], deployer.address);
    assertEquals(bond['partner2'], partner.address);
    assertEquals(bond['status'], "active");
    assertEquals(bond['points'], "u0");
    assertEquals(bond['tier'], "bronze");
  },
});

Clarinet.test({
  name: "Can earn points and upgrade tier through activities",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const partner = accounts.get('wallet_1')!;
    
    // Create bond
    let bondBlock = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'create-bond', [
        types.principal(partner.address)
      ], deployer.address)
    ]);
    
    // Complete date nights to earn points
    let futureBlock = chain.blockHeight + 100;
    for(let i = 0; i < 5; i++) {
      let scheduleBlock = chain.mineBlock([
        Tx.contractCall('sphere-bond', 'schedule-date-night', [
          types.uint(1),
          types.uint(futureBlock),
          types.ascii("Date night " + i)
        ], deployer.address)
      ]);
      
      let completeBlock = chain.mineBlock([
        Tx.contractCall('sphere-bond', 'complete-date-night', [
          types.uint(1),
          types.uint(i + 1)
        ], deployer.address)
      ]);
    }
    
    // Check updated bond tier
    let bondCheck = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'get-bond', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    let bond = bondCheck.receipts[0].result.expectOk().expectSome();
    assertEquals(bond['points'], "u250"); // 5 dates * 50 points
    assertEquals(bond['tier'], "silver");
  },
});

Clarinet.test({
  name: "Can create and redeem rewards",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const partner = accounts.get('wallet_1')!;
    
    // Create bond and earn points
    let bondBlock = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'create-bond', [
        types.principal(partner.address)
      ], deployer.address)
    ]);
    
    // Add milestones to earn points
    for(let i = 0; i < 3; i++) {
      let milestoneBlock = chain.mineBlock([
        Tx.contractCall('sphere-bond', 'add-milestone', [
          types.uint(1),
          types.ascii("Milestone " + i),
          types.ascii("Description " + i)
        ], deployer.address)
      ]);
    }
    
    // Create reward
    let rewardBlock = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'create-reward', [
        types.ascii("Special Date"),
        types.ascii("A romantic evening"),
        types.uint(200),
        types.ascii("bronze")
      ], deployer.address)
    ]);
    
    // Redeem reward
    let redeemBlock = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'redeem-reward', [
        types.uint(1),
        types.uint(1)
      ], deployer.address)
    ]);
    
    redeemBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Check remaining points
    let bondCheck = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'get-bond', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    let bond = bondCheck.receipts[0].result.expectOk().expectSome();
    assertEquals(bond['points'], "u100"); // 300 earned - 200 spent
  },
});
