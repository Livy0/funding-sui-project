#[test_only]
module fund::fund_contract_test {
    use sui::test_scenario as ts;
    use sui::coin::{Self,Coin,mint_for_testing};
    use sui::sui::SUI;
    use sui::tx_context::TxContext;
    use sui::object::UID;
    use sui::balance;

    use supra_holder:: SupraSValueFeed::{Self, OracleHolder};
    use fund::fund_contract as fc;
    use fund::fund_contract::{Fund,FundOwnerCap};

#[test]

   
   fun create_fund_test()  { 

   let owner: address = @0xA;
   let user1: address = @0xB;
   let user2: address = @0xC;

   
   let scenario_test = ts::begin(owner);
   let scenario = &mut scenario_test;

   ts::next_tx(scenario, owner);

   {
     SupraSValueFeed::create_oracle_holder_for_test(ts::ctx(scenario))
   };

    ts::next_tx(scenario, owner);
    {
        let oracle_holder = ts::take_shared<OracleHolder>(scenario);
        SupraSValueFeed::add_pair_data(
            &mut oracle_holder, 90, 1800_000000000000000000, 18, 1704693072240, 6489821);
        ts::return_shared(oracle_holder);
    };

   ts::next_tx(scenario,user1);
   {
     let target: u64 = 100000;
     fc::create_fund(target,ts::ctx(scenario));
   };

   ts::next_tx(scenario,user1);
   {
     let target: u64 = 100000;
     let fund = ts::take_shared<Fund>(scenario);

     let fund_target = fc::get_target(&fund);
        assert!(fund_target == target, 0);

     let fund_raised = fc::get_raised(&fund);
        assert!(fund_raised == 0, 0);


     let fund_owner_cap = ts::take_from_sender<FundOwnerCap>(scenario);
     ts::return_to_sender(scenario,fund_owner_cap);
     ts::return_shared(fund);
   };
   
   ts::next_tx(scenario,user2);
   {
   let fund = ts::take_shared<Fund>(scenario);
   let oracle_holder = ts::take_shared<OracleHolder>(scenario);
   let donation_amount = mint_for_testing<SUI>(1000,ts::ctx(scenario));
  
   fc::donate(&oracle_holder, &mut fund, donation_amount,ts::ctx(scenario));

   let fund_raised = fc::get_raised(&fund);
   assert!(fund_raised == 1000 , 0);

   ts::return_shared(oracle_holder);
   ts::return_shared(fund);
   };

   ts::next_tx(scenario,user1);

   {
    let fund_owner_cap = ts::take_from_sender<FundOwnerCap>(scenario);
    let fund = ts::take_shared<Fund>(scenario);


   fc::withdraw_funds(&fund_owner_cap,&mut fund,ts::ctx(scenario));

   let fund_raised = fc::get_raised(&fund);
   assert!(fund_raised == 0 , 0);

   ts::return_to_sender(scenario,fund_owner_cap);
   ts::return_shared(fund);
   };

   ts::end(scenario_test);
   }

}