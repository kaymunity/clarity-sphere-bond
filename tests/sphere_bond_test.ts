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
  },
});

Clarinet.test({
  name: "Can schedule and complete a date night",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const partner = accounts.get('wallet_1')!;
    
    // Create bond first
    let bondBlock = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'create-bond', [
        types.principal(partner.address)
      ], deployer.address)
    ]);
    
    // Schedule date night
    let futureBlock = chain.blockHeight + 100;
    let scheduleBlock = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'schedule-date-night', [
        types.uint(1),
        types.uint(futureBlock),
        types.ascii("Dinner and movie")
      ], deployer.address)
    ]);
    
    scheduleBlock.receipts[0].result.expectOk().expectUint(1);
    
    // Complete date night
    let completeBlock = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'complete-date-night', [
        types.uint(1),
        types.uint(1)
      ], deployer.address)
    ]);
    
    completeBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Verify date night status
    let checkBlock = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'get-date-night', [
        types.uint(1),
        types.uint(1)
      ], deployer.address)
    ]);
    
    let dateNight = checkBlock.receipts[0].result.expectOk().expectSome();
    assertEquals(dateNight['completed'], true);
  },
});

Clarinet.test({
  name: "Can add and retrieve milestones",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const partner = accounts.get('wallet_1')!;
    
    // Create bond first
    let bondBlock = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'create-bond', [
        types.principal(partner.address)
      ], deployer.address)
    ]);
    
    // Add milestone
    let milestoneBlock = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'add-milestone', [
        types.uint(1),
        types.ascii("First Date"),
        types.ascii("Had our first date at Central Park")
      ], deployer.address)
    ]);
    
    milestoneBlock.receipts[0].result.expectOk().expectUint(1);
    
    // Check milestone
    let checkBlock = chain.mineBlock([
      Tx.contractCall('sphere-bond', 'get-milestone', [
        types.uint(1),
        types.uint(1)
      ], deployer.address)
    ]);
    
    let milestone = checkBlock.receipts[0].result.expectOk().expectSome();
    assertEquals(milestone['title'], "First Date");
  },
});