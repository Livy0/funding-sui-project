module crowd_fund::fund_contract {
  
  use sui::object::{Self, UID, ID};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use sui::coin::{Self, Coin};
  use sui::balance::{Self, Balance};
  use sui::sui::SUI;
  use sui::event;
  use SupraOracle::SupraSValueFeed::{get_price, OracleHolder};


  // ====== Errors ======

  const ENotFundOwner: u64 = 1; // Updated error code to avoid conflict
  const EInsufficientFunds: u64 = 2; // Added error code for insufficient funds


  // ====== Objects ======
  
  struct Fund has key {
    fund_id: UID,
    target: u64, // in USD 
    raised: Balance<SUI>,
  }

  struct Receipt has key {
    id: UID, 
    amount_donated: u64, // in SUI
  }

  // Capability that grants a fund creator the right to withdraw funds.
  struct FundOwnerCap has key { 
    fund_id: ID,
  }


  // ====== Events ======

  // For when the fund target is reached.
  struct TargetReached has copy, drop {
      raised_amount_sui: u128,
    }


   // ====== Functions ======

  public entry fun create_fund(target: u64, ctx: &mut TxContext) {
    let fund_uid = object::new(ctx);
    let fund_id: ID = object::uid_to_inner(&fund_uid);

    let fund = Fund {
        fund_id: fund_uid,
        target,
        raised: balance::zero(),
    };

    // create and send a fund owner capability for the creator
    transfer::transfer(FundOwnerCap {
          fund_id: fund_id,
        }, tx_context::sender(ctx));

    // share the object so anyone can donate
    transfer::share_object(fund);
  }

  public entry fun donate(oracle_holder: &OracleHolder, fund: &mut Fund, amount: Coin<SUI>, ctx: &mut TxContext) {

    // Check for authorized donor
    assert!(tx_context::sender(ctx) != fund.fund_id, ENotFundOwner);

    // get the amount being donated in SUI for receipt.
    let amount_donated: u64 = coin::value(&amount);

    // add the amount to the fund's balance
    let coin_balance = coin::into_balance(amount);
    balance::join(&mut fund.raised, coin_balance);

    // get price of SUI in USD using Supra's Oracle SValueFeed
    let (price, _,_,_) = get_price(oracle_holder, 90);

    // calculate total raised amount in SUI
    let raised_amount_sui = (balance::value(&fund.raised) as u128);

    // calculate total raised amount in USD
    let raised_amount_usd = (raised_amount_sui * price) / 1000000000; // adjusting decimals

    // check if the fund target in USD has been reached
    if raised_amount_usd >= fund.target {
      // emit event that the target has been reached
        event::emit(TargetReached { raised_amount_sui });
    };
      
    // create and send receipt NFT to the donor
    let receipt: Receipt = Receipt {
        id: object::new(ctx), 
        amount_donated,
      };
      
    transfer::transfer(receipt, tx_context::sender(ctx));
  }

  // withdraw funds from the fund contract, requires a fund owner capability that matches the fund id
  public entry fun withdraw_funds(cap: &FundOwnerCap, fund: &mut Fund, ctx: &mut TxContext) {

    assert!(cap.fund_id == fund.fund_id, ENotFundOwner);

    let amount: u64 = balance::value(&fund.raised);

    if amount == 0 {
      return Err(EInsufficientFunds);
    }

    let raised: Coin<SUI> = coin::take(&mut fund.raised, amount, ctx);

    transfer::public_transfer(raised, tx_context::sender(ctx));   
  }

  // Getter functions for fund details
  public fun get_fund_target(fund: &Fund) -> u64 {
    fund.target
  }

  public fun get_raised_amount_sui(fund: &Fund) -> u64 {
    balance::value(&fund.raised)
  }

  public fun get_raised_amount_usd(oracle_holder: &OracleHolder, fund: &Fund) -> u64 {
    let (price, _,_,_) = get_price(oracle_holder, 90);
    let raised_amount_sui = balance::value(&fund.raised) as u128;
    (raised_amount_sui * price) / 1000000000
  }
}
