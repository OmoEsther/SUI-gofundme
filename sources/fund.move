module goFundMe::fund_contract {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::event;

    const ENotFundOwner: u64 = 30;
    const ETargetReached: u64 = 31;
    const ETargetNotReached: u64 = 32;

    // The Fund Object
    struct Fund has key {
        id: UID,
        target: u64,
        raised: Balance<SUI>,
        target_reached: bool,
    }

    // The Receipt NFT to show verify that user has donated to a fund
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
    public fun createFund(target: u64, ctx: &mut TxContext): FundOwner {
        // create the fund object
        let fund = Fund {
            id: object::new(ctx),
            target,
            raised: balance::zero(),
            target_reached: false
        };

        // get the Id from the UID
        let fund_id = object::uid_to_inner(&fund.id); 

        // share fund to everyone
        transfer::share_object(fund);

        // give creatorfund owner permission rights
        FundOwner{
            id: object::new(ctx),
            fund_id,
        }
    }

    // The donate function
    public fun donate(fund: &mut Fund, amount: Coin<SUI>, ctx: &mut TxContext): Receipt {  
        // check that funding target has not been reached
        assert!(!fund.target_reached, ETargetReached);

        // get the amount being donated in SUI for receipt
        let amount_donated = coin::value(&amount);

        // add the amount to the fund's balance
        let coin_balance = coin::into_balance(amount);
        balance::join(&mut fund.raised, coin_balance);

        // get the total raised amount 
        let raised_amount_sui = balance::value(&fund.raised);

        if (raised_amount_sui >= fund.target){
            // emit event
            event::emit(TargetReached { raised_amount_sui });
            fund.target_reached = true;
        };

        // create and send receipt NFT to the donor
        Receipt {
            id: object::new(ctx),
            amount_donated
        }
    }

    // withdraw funds from the fund contract, requiring a FundOwner that matches the fund id
    public fun withdrawFunds(owner: &FundOwner, fund: &mut Fund, ctx: &mut TxContext): Coin<SUI> {
        assert!(&owner.fund_id == object::uid_as_inner(&fund.id), ENotFundOwner);

        // check that target has been reached
        assert!(fund.target_reached, ETargetNotReached);

        // get the balance
        let amount = balance::value(&fund.raised);

        // wrap balance with coin
        let raised = coin::take(&mut fund.raised, amount, ctx);

        raised
    }

    // === Getter functions ====

    /// Return the amount raised
    public fun getFundsRaised(self: &Fund): u64 {
        balance::value(&self.raised)
    }
}