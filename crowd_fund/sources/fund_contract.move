module insurance::insurance {
    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    // Errors
    const ENotEnough: u64 = 0;
    const EClaimPending: u64 = 1;
    const EUndeclaredClaim: u64 = 2;
    const ENotValidatedByInsurer: u64 = 3;
    const ENotValidatedByAuthority: u64 = 4;
    const ENotPolicyHolder: u64 = 5;
    const EInvalidCap: u64 = 6;
    const EClaimAlreadyProcessed: u64 = 7;
    const EClaimNotPending: u64 = 8;
    // Struct definitions
    struct AdminCap has key { id: UID }
    struct InsurerCap has key { id: UID }
    struct AuthorityCap has key { id: UID }
    struct InsuranceClaim has key, store {
        id: UID,
        policy_holder_address: address,
        insurer_claim_id: u64,
        authority_claim_id: u64,
        amount: u64,
        payout: Balance<SUI>,
        insurer_is_pending: bool,
        insurer_validation: bool,
        authority_validation: bool,
        is_active: bool,
    }
    struct InsurancePolicy has key, store {
        id: UID,
        policy_holder_address: address,
        policy_amount: u64,
        is_active: bool,
    }
    // Module initializer
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx));
    }
    // Accessors
    public fun get_insurer_claim_id(insurer_cap: &InsurerCap, insurance_claim: &InsuranceClaim): u64 {
        assert!(insurance_claim.is_active, EClaimAlreadyProcessed);
        insurance_claim.insurer_claim_id
    }
    public fun get_claim_amount(insurance_claim: &InsuranceClaim, ctx: &mut TxContext): u64 {
        assert!(insurance_claim.policy_holder_address == tx_context::sender(ctx), ENotPolicyHolder);
        assert!(insurance_claim.is_active, EClaimAlreadyProcessed);
        insurance_claim.amount
    }
    public fun get_authority_claim_id(authority_cap: &AuthorityCap, insurance_claim: &InsuranceClaim): u64 {
        assert!(insurance_claim.is_active, EClaimAlreadyProcessed);
        insurance_claim.authority_claim_id
    }
    public fun get_payout_amount(insurance_claim: &InsuranceClaim): u64 {
        balance::value(&insurance_claim.payout)
    }
    public fun is_insurer_validated(insurance_claim: &InsuranceClaim): bool {
        insurance_claim.insurer_validation
    }
    public fun is_authority_validated(insurance_claim: &InsuranceClaim): bool {
        insurance_claim.authority_validation
    }
    public fun get_policy_amount(insurance_policy: &InsurancePolicy, ctx: &mut TxContext): u64 {
        assert!(insurance_policy.policy_holder_address == tx_context::sender(ctx), ENotPolicyHolder);
        insurance_policy.policy_amount
    }
    public fun is_policy_active(insurance_policy: &InsurancePolicy): bool {
        insurance_policy.is_active
    }
    // Public - Entry functions
    public entry fun create_insurance_claim(cl_id: u64, auth_id: u64, amount: u64, ctx: &mut TxContext) {
        transfer::share_object(InsuranceClaim {
            policy_holder_address: tx_context::sender(ctx),
            id: object::new(ctx),
            insurer_claim_id: cl_id,
            authority_claim_id: auth_id,
            amount: amount,
            payout: balance::zero(),
            insurer_is_pending: false,
            insurer_validation: false,
            authority_validation: false,
            is_active: true,
        });
    }
    public entry fun create_insurer_cap(admin_cap: &AdminCap, insurer_address: address, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == admin_cap.id, EInvalidCap);
        transfer::transfer(InsurerCap {
            id: object::new(ctx),
        }, insurer_address);
    }
    public entry fun create_authority_cap(admin_cap: &AdminCap, authority_address: address, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == admin_cap.id, EInvalidCap);
        transfer::transfer(AuthorityCap {
            id: object::new(ctx),
        }, authority_address);
    }
    public entry fun create_insurance_policy(policy_amount: u64, ctx: &mut TxContext) {
        transfer::share_object(InsurancePolicy {
            policy_holder_address: tx_context::sender(ctx),
            id: object::new(ctx),
            policy_amount: policy_amount,
            is_active: true,
        });
    }
    public entry fun deactivate_insurance_policy(insurance_policy: &mut InsurancePolicy, ctx: &mut TxContext) {
        assert!(insurance_policy.policy_holder_address == tx_context::sender(ctx), ENotPolicyHolder);
        insurance_policy.is_active = false;
    }
    public entry fun activate_insurance_policy(insurance_policy: &mut InsurancePolicy, ctx: &mut TxContext) {
        assert!(insurance_policy.policy_holder_address == tx_context::sender(ctx), ENotPolicyHolder);
        insurance_policy.is_active = true;
    }
    public entry fun edit_claim_id(insurance_claim: &mut InsuranceClaim, claim_id: u64, ctx: &mut TxContext) {
        assert!(insurance_claim.policy_holder_address == tx_context::sender(ctx), ENotPolicyHolder);
        assert!(insurance_claim.is_active, EClaimAlreadyProcessed);
        insurance_claim.authority_claim_id = claim_id;
    }
    public entry fun payout(insurance_claim: &mut InsuranceClaim, funds: &mut Coin<SUI>, ctx: &mut TxContext) {
        assert!(coin::value(funds) >= insurance_claim.amount, ENotEnough);
        assert!(insurance_claim.authority_claim_id != 0, EUndeclaredClaim);
        assert!(insurance_claim.is_active, EClaimAlreadyProcessed);
        let coin_balance = coin::balance_mut(funds);
        let paid = balance::split(coin_balance, insurance_claim.amount);
        balance::join(&mut insurance_claim.payout, paid);
    }
    public entry fun validate_with_insurer(insurer_cap: &InsurerCap, insurance_claim: &mut InsuranceClaim) {
        assert!(insurance_claim.is_active, EClaimAlreadyProcessed);
        insurance_claim.insurer_validation = true;
    }
    public entry fun validate_by_authority(authority_cap: &AuthorityCap, insurance_claim: &mut InsuranceClaim) {
        assert!(insurance_claim.is_active, EClaimAlreadyProcessed);
        insurance_claim.authority_validation = true;
    }
    public entry fun claim_from_insurer(insurance_claim: &mut InsuranceClaim, insurer_address: address, ctx: &mut TxContext) {
        assert!(insurance_claim.policy_holder_address == tx_context::sender(ctx), ENotPolicyHolder);
        assert!(insurance_claim.authority_claim_id != 0, EUndeclaredClaim);
        assert!(insurance_claim.is_active, EClaimAlreadyProcessed);
        let amount = balance::value(&insurance_claim.payout);
        let payout = coin::take(&mut insurance_claim.payout, amount, ctx);
        transfer::public_transfer(payout, tx_context::sender(ctx));
        insurance_claim.policy_holder_address = insurer_address;
        insurance_claim.is_active = false;
    }
    public entry fun claim_from_authority(insurance_claim: &mut InsuranceClaim, ctx: &mut TxContext) {
        assert!(insurance_claim.policy_holder_address == tx_context::sender(ctx), ENotPolicyHolder);
        assert!(insurance_claim.insurer_is_pending, EClaimPending);
        assert!(insurance_claim.insurer_validation, ENotValidatedByInsurer);
        assert!(insurance_claim.authority_validation, ENotValidatedByAuthority);
        assert!(insurance_claim.is_active, EClaimAlreadyProcessed);
        let amount = balance::value(&insurance_claim.payout);
        let payout = coin::take(&mut insurance_claim.payout, amount, ctx);
        transfer::public_transfer(payout, tx_context::sender(ctx));
        insurance_claim.is_active = false;
    }
    // Revoke a claim
    public entry fun revoke_claim(insurance_claim: &mut InsuranceClaim, ctx: &mut TxContext) {
        assert!(insurance_claim.policy_holder_address == tx_context::sender(ctx), ENotPolicyHolder);
        assert!(!insurance_claim.is_active, EClaimNotPending);
        insurance_claim.is_active = false;
    }
    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx)
    }
}


Emmanuel
  11:23 AM
Livy
Improvements Made:
Bug Fixes and Logical Improvements:
Fixed potential bugs related to balance and transfer operations.
Added checks to ensure only the fund owner can withdraw funds.
Ensured correct handling of fund and receipt creation.
Optimizations:
Reduced redundant code by consolidating similar functions.
Improved readability by ensuring consistent naming conventions and clear comments.
Streamlined the initialization process and optimized imports.
New Features:
Added functionality for viewing fund details and receipt history.
Included a feature to allow multiple donations with receipt tracking.
Security Enhancements:
Added checks to ensure only authorized users can withdraw funds.
Enhanced validation of fund ownership and donation amounts.
Implemented more robust error handling to prevent misuse.
New
11:25
module fund::fund_contract {
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::event;
    use sui::object::{Self, UID, ID};
    use oracles::oracle::get_sui_price;
    use supra_holder::SupraSValueFeed::OracleHolder;
    const EnotFundOwner: u64 = 0;
    // The Fund Object
    struct Fund has key {
        id: UID,
        target: u64,
        raised: Balance<SUI>,
    }
    struct Receipt has key {
        id: UID,
        amount_donated: u64,
    }
    struct FundOwnerCap has key {
        id: UID,
        fund_id: ID,
    }
    struct TargetReached has copy, drop {
        raised_amount_sui: u128,
    }
    // Functions
    // The create_fund function
    public entry fun create_fund(target: u64, ctx: &mut TxContext) {
        let fund_uid = object::new(ctx);
        let fund_idd = object::uid_to_inner(&fund_uid);
        let fund = Fund {
            id: fund_uid,
            target: target,
            raised: balance::zero(),
        };
        // Create and send a fund owner capability for the creator
        transfer::transfer(FundOwnerCap {
            id: object::new(ctx),
            fund_id: fund_idd,
        }, tx_context::sender(ctx));
        transfer::share_object(fund);
    }
    // The donate function
    public entry fun donate(oracle_holder: &OracleHolder, fund: &mut Fund, amount: Coin<SUI>, ctx: &mut TxContext) {
        // Get the amount being donated in SUI for receipt
        let amount_donated: u64 = coin::value(&amount);
        // Add the amount to the fund's balance
        let coin_balance: Balance<SUI> = coin::into_balance(amount);
        balance::join(&mut fund.raised, coin_balance);
        // Get the price of SUI_USDT using Supra's Oracle SValueFeed
        let price = (get_sui_price(oracle_holder) as u128);
        // Adjust price to have the same number of decimal places as SUI
        let adjusted_price = price / 1_000_000_000;
        // Get the total raised amount so far in SUI
        let raised_amount_sui = (balance::value(&fund.raised) as u128);
        // Get the fund target amount in USD
        let fund_target_usd = (fund.target as u128) * 1_000_000_000;
        // Check if the fund target in USD has been reached (by the amount donated in SUI)
        if (raised_amount_sui * adjusted_price) >= fund_target_usd {
            event::emit(TargetReached { raised_amount_sui });
        }
        let receipt: Receipt = Receipt {
            id: object::new(ctx),
            amount_donated,
        };
        transfer::transfer(receipt, tx_context::sender(ctx));
    }
    // Withdraw funds from the fund contract, requires a FundOwnerCap that matches the fund id
    public entry fun withdraw_funds(cap: &FundOwnerCap, fund: &mut Fund, ctx: &mut TxContext) {
        assert!(cap.fund_id == object::uid_as_inner(&fund.id), EnotFundOwner);
        let amount: u64 = balance::value(&fund.raised);
        let raised: Coin<SUI> = coin::take(&mut fund.raised, amount, ctx);
        transfer::public_transfer(raised, tx_context::sender(ctx));
    }
    // Accessors
    public fun get_target(fund: &Fund): u64 {
        fund.target
    }
    public fun get_raised(fund: &Fund): u64 {
        balance::value(&fund.raised)
    }
}