module goFundMe::fund_contract {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::event;
    use sui::vec_map::{Self, VecMap};
    use std::option::{Option};

    const ENotFundOwner: u64 = 30;
    const ETargetReached: u64 = 31;

    // The map to keep track of created funds
    struct FundContract has key, store{
        id: UID,
        next_idx: u32,
        funds_map: VecMap<u32, ID>,
        owners_map: VecMap<address, ID>,
    }

    // The Fund Object
    struct Fund has key {
        id: UID,
        target: u64,
        raised: Balance<SUI>,
        target_reached: bool,
    }

    // The Receipt NFT to show verify that user has donated to a fund
    struct Receipt has key {
        id: UID,
        amount_donated: u64, // in MIS, 10^-9 of SUI.
    }

    // The FundOwner Object
    struct FundOwner has key {
        id: UID,
        fund_id: ID,
    }

    // The TargetReached Event
    struct TargetReached has copy, drop {
        raised_amount_sui: u128,
    }

    // init function ran as fund contract is published
    fun init(ctx: &mut TxContext) {
        // create empty map
        let funds_map = vec_map::empty<u32, ID>();
        let owners_map = vec_map::empty<address, ID>();

        // create the fund contract
        let fund_contract = FundContract {
            id: object::new(ctx),
            next_idx: 0,
            funds_map,
            owners_map,
        };

        // share object to everyone
        transfer::share_object(fund_contract);
    }

    // The create_fund function
    public entry fun create_fund(fundContract: &mut FundContract, target: u64, ctx: &mut TxContext){
        // get txn sender 
        let sender = tx_context::sender(ctx);

        // create the fund object
        let fund = Fund {
            id: object::new(ctx),
            target,
            raised: balance::zero(),
            target_reached: false
        };

        // get the Id from the UID
        let fund_id = object::uid_to_inner(&fund.id);

        // create the owner object for fund owner
        let owner = FundOwner{
            id: object::new(ctx),
            fund_id,
        };

        // get owner id
        let owner_id = object::uid_to_inner(&owner.id);

        // gen prev fund id
        let prev_idx = fundContract.next_idx;

        // add fund idx to fund_contract map
        vec_map::insert(&mut fundContract.funds_map, prev_idx, fund_id);

        // add owner idx to fund_contract map
        vec_map::insert(&mut fundContract.owners_map, sender, owner_id);

        // increment the fund ids
        fundContract.next_idx = prev_idx + 1;

        // create and send a fund owner capabilty for the creator
        transfer::transfer(owner, sender);

        // share fund to everyone
        transfer::share_object(fund);
    }

    public fun get_all_funds(fundContract: &FundContract): vector<ID> {
        let (_, values) = vec_map::into_keys_values(fundContract.funds_map);
        values
    }

    public fun get_fund_by_idx(fundContract: &FundContract, fundIdx: u32): Option<ID> {
        let fund_id = vec_map::try_get(&fundContract.funds_map, &fundIdx);

        fund_id
    }

    public fun get_owner_by_address(fundContract: &FundContract, addr: address): Option<ID> {
        let owner_id = vec_map::try_get(&fundContract.owners_map, &addr);

        owner_id
    }

    // The donate function
    public entry fun donate(fund: &mut Fund, amount: Coin<SUI>, ctx: &mut TxContext) {  
        // check that funding target has not been reached
        assert!(!fund.target_reached, ETargetReached);

        // get the amount being donated in SUI for receipt
        let amount_donated = coin::value(&amount);

        // add the amount to the fund's balance
        let coin_balance = coin::into_balance(amount);
        balance::join(&mut fund.raised, coin_balance);

        // get the total raised amount 
        let raised_amount_sui = (balance::value(&fund.raised) as u128);
        
        // get the fund target amount in 10^9
        let target_amount_sui = (fund.target * 1000000000 as u128);

        if (raised_amount_sui >= target_amount_sui){
            // emit event
            event::emit(TargetReached { raised_amount_sui });
            fund.target_reached = true;
        };

        // create and send receipt NFT to the donor
        let receipt = Receipt {
            id: object::new(ctx),
            amount_donated
        };

        transfer::transfer(receipt, tx_context::sender(ctx));
    }

    // withdraw funds from the fund contract, requiring a FundOwner that matches the fund id
    public entry fun withdraw_funds(owner: &FundOwner, fund: &mut Fund, ctx: &mut TxContext) {
        assert!(&owner.fund_id == object::uid_as_inner(&fund.id), ENotFundOwner);

        let amount = balance::value(&fund.raised);

        let raised = coin::take(&mut fund.raised, amount, ctx);

        transfer::public_transfer(raised, tx_context::sender(ctx));
    }
}