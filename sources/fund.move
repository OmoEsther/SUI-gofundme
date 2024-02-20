module goFundMe::fund_contract {
    use sui::object::{self, UID, ID, new, uid_to_inner, uid_as_inner};
    use sui::transfer::{self, public_transfer};
    use sui::tx_context::TxContext;
    use sui::coin::{self, Coin, mint_for_testing, value as coin_value, into_balance, take};
    use sui::balance::{self, Balance, zero, join};
    use sui::sui::SUI;
    use sui::event;

    const E_NOT_FUND_OWNER: u64 = 30;
    const E_TARGET_REACHED: u64 = 31;
    const E_TARGET_NOT_REACHED: u64 = 32;

    // The Fund Object
    struct Fund has key {
        id: UID,
        target: u64,
        raised: Balance<SUI>,
        target_reached: bool,
    }

    // The Receipt NFT to verify that a user has donated to a fund
    struct Receipt has key, store {
        id: UID,
        amount_donated: u64, // in MIS, 10^-9 of SUI.
    }

    // The FundOwner Object
    struct FundOwner has key, store {
        id: UID,
        fund_id: ID,
    }

    // The TargetReached Event
    struct TargetReached has copy, drop {
        raised_amount_sui: u64,
    }

    // The create_fund function
    public fun create_fund(target: u64, ctx: &mut TxContext) -> FundOwner {
        // Create the fund object
        let fund = Fund {
            id: new(ctx),
            target,
            raised: zero(),
            target_reached: false
        };

        // Share fund to everyone
        transfer::share_object(fund);

        // Give fund owner permission rights
        FundOwner {
            id: new(ctx),
            fund_id: uid_to_inner(&fund.id),
        }
    }

    // The donate function
    public fun donate(fund: &mut Fund, amount: Coin<SUI>, ctx: &mut TxContext) -> Receipt {  
        // Check that funding target has not been reached
        assert!(!fund.target_reached, E_TARGET_REACHED);

        // Get the amount being donated in SUI for receipt
        let amount_donated = coin_value(&amount);

        // Add the amount to the fund's balance
        let coin_balance = into_balance(amount);
        join(&mut fund.raised, coin_balance);

        // Get the total raised amount 
        let raised_amount_sui = balance::value(&fund.raised);

        if raised_amount_sui >= fund.target {
            // Emit event
            event::emit(TargetReached { raised_amount_sui });
            fund.target_reached = true;
        }

        // Create and send receipt NFT to the donor
        Receipt {
            id: new(ctx),
            amount_donated
        }
    }

    // Withdraw funds from the fund contract, requiring a FundOwner that matches the fund id
    public fun withdraw_funds(owner: &FundOwner, fund: &mut Fund, ctx: &mut TxContext) -> Coin<SUI> {
        assert!(owner.fund_id == uid_as_inner(&fund.id), E_NOT_FUND_OWNER);

        // Check that target has been reached
        assert!(fund.target_reached, E_TARGET_NOT_REACHED);

        // Get the balance
        let amount = balance::value(&fund.raised);

        // Wrap balance with coin
        let raised = take(&mut fund.raised, amount, ctx);

        raised
    }

    // Getter function to return the amount raised
    public fun get_funds_raised(fund: &Fund) -> u64 {
        balance::value(&fund.raised)
    }

    // Tests
    #[test_only] use sui::test_scenario as ts;
    #[test_only] const OWNER: address = @0xAD;
    #[test_only] const ALICE: address = @0xA;
    #[test_only] const BOB: address = @0xB;

    // Test the create 
    #[test]
    fun test_gofundme() {
        let ts = ts::begin(@0x0);

        // FundOwner creates a fund me campaign
        {
            ts::next_tx(&mut ts, OWNER);
            let target: u64 = 50; // 50 SUI tokens
            // Create owner cap for fund
            let fund_owner_cap = create_fund(target, ts::ctx(&mut ts));
            // Transfer cap to owner
            public_transfer(fund_owner_cap, OWNER);
        }

        // Alice donates 25 SUI tokens to the campaign
        {
            ts::next_tx(&mut ts, ALICE);
            let fund = ts::take_shared(&ts);
            let coin = mint_for_testing<SUI>(25, ts::ctx(&mut ts));
            let receipt = donate(&mut fund, coin, ts::ctx(&mut ts));

            // Transfer receipt to Alice
            public_transfer(receipt, ALICE);

            assert!(get_funds_raised(&fund) == 25);
            ts::return_shared(fund);
        }

        // Bob donates 35 SUI tokens to the campaign
        {
            ts::next_tx(&mut ts, BOB);
            let fund = ts::take_shared(&ts);
            let coin = mint_for_testing<SUI>(35, ts::ctx(&mut ts));
            let receipt = donate(&mut fund, coin, ts::ctx(&mut ts));

            // Transfer receipt to Bob
            public_transfer(receipt, BOB);

            assert!(get_funds_raised(&fund) == 60);
            ts::return_shared(fund);
        }

        // Owner withdraws the fund        
        {
            ts::next_tx(&mut ts, OWNER);
            let owner_cap: FundOwner = ts::take_from_sender(&ts);
            let fund: Fund = ts::take_shared(&ts);
            
            let coin = withdraw_funds(&owner_cap, &mut fund, ts::ctx(&mut ts));
            
            public_transfer(coin, OWNER);

            ts::return_shared(fund);
            ts::return_to_sender(&ts, owner_cap);
        }

        ts::end(ts);
    }

    #[test]
    #[expected_failure]
    fun test_owner_should_not_be_able_to_withdraw_if_target_not_reached() {
        let ts = ts::begin(@0x0);

        // FundOwner creates a fund me campaign
        {
            ts::next_tx(&mut ts, OWNER);
            let target: u64 = 50; // 50 SUI tokens
            // Create owner cap for fund
            let fund_owner_cap = create_fund(target, ts::ctx(&mut ts));
            // Transfer cap to owner
            public_transfer(fund_owner_cap, OWNER);
        }

        // Alice donates 25 SUI tokens to the campaign
        {
            ts::next_tx(&mut ts, ALICE);
            let fund = ts::take_shared(&ts);
            let coin = mint_for_testing<SUI>(25, ts::ctx(&mut ts));
            let receipt = donate(&mut fund, coin, ts::ctx(&mut ts));

            // Transfer receipt to Alice
                        public_transfer(receipt, ALICE);

            assert!(get_funds_raised(&fund) == 25);
            ts::return_shared(fund);
        }

         // Owner withdraws the fund        
         {
            ts::next_tx(&mut ts, OWNER);
            let ownerCap: FundOwner = ts::take_from_sender(&ts);
            let fund: Fund = ts::take_shared(&ts);
            
            let coin = withdraw_funds(&ownerCap, &mut fund, ts::ctx(&mut ts));
            
            public_transfer(coin, OWNER);

            ts::return_shared(fund);
            ts::return_to_sender(&ts, ownerCap);
        }

        ts::end(ts);
    }

    #[test]
    #[expected_failure]
    fun test_user_cannot_deposit_after_target_reached() {
        let ts = ts::begin(@0x0);

        // FundOwner creates a fund me campaign
        {
            ts::next_tx(&mut ts, OWNER);
            let target: u64 = 50; // 50 SUI tokens
            // Create owner cap for fund
            let fundOwnerCap = createFund(target, ts::ctx(&mut ts));
            // Transfer cap to owner
            transfer::public_transfer(fundOwnerCap, OWNER);
        }

        // Alice donates 50 SUI tokens to the campaign
        {
            ts::next_tx(&mut ts, ALICE);
            let fund = ts::take_shared(&ts);
            let coin = coin::mint_for_testing<SUI>(50, ts::ctx(&mut ts));
            let receipt = donate(&mut fund, coin, ts::ctx(&mut ts));

            // Transfer receipt to Alice
            transfer::public_transfer(receipt, ALICE);

            assert!(getFundsRaised(&fund) == 50, 0);

            ts::return_shared(fund);
        }

        // Bob donates 35 SUI tokens to the campaign
        {
            ts::next_tx(&mut ts, BOB);
            let fund = ts::take_shared(&ts);
            let coin = coin::mint_for_testing<SUI>(35, ts::ctx(&mut ts));
            let receipt = donate(&mut fund, coin, ts::ctx(&mut ts));

            // Transfer receipt to Bob
            transfer::public_transfer(receipt, BOB);

            assert!(getFundsRaised(&fund) == 85, 0);

            ts::return_shared(fund);
        }

        ts::end(ts);
    }
}
