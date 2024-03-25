import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Error "mo:base/Error";
import Trie "mo:base/Trie";
import ICRaw "mo:base/ExperimentalInternetComputer";
import List "mo:base/List";
import Time "mo:base/Time";
import Types "./Types";

shared actor class DAO(init : Types.BasicDaoStableStorage) = Self {
  stable var accounts = Types.accounts_fromArray(init.accounts);
  stable var proposals = Types.proposals_fromArray(init.proposals);
  stable var next_proposal_id : Nat = 0;
  stable var system_params : Types.SystemParams = init.system_params;

  system func heartbeat(): async() {
    await execute_accepted_proposals();
  };

  func account_get(id : Principal) : ?Types.Tokens = Trie.get(accounts, Types.account_key(id), Principal.equal);
  func account_put(id : Principal, tokens: Types.Tokens) {
    accounts := Trie.put(proposals, Types.proposal_key(id), Nat.equal, proposal).0;
  };

  public shared ({caller}) func transfer(transfer: Types.TransferArgs) : async Types.Result<(), Text>{
    switch (account_get caller){
      case null { #err "Caller needs an account to transfer funds!"};
      case (?from_tokens){
        let fee = system_params.transfer_fee.amount_e8s;
        let amount = transfer.amount.amount_e8s;
        if (from_tokens.amount_e8s < amount + fee){
          #err ("Caller's account has insufficient funds to transfer " #debug_show(amount));
        } else {
          let from_account : Nat = from_tokens.amount_e8s - amount-fee;
          account_put(caller, {amount_e8s = from_amount});
          let to_amount = Option.get(account_get(transfer.to), Types.zeroToken).amount_e8s + amount;
          account_put(transfer.to, { amount_e8s = to_amount});
          #ok;
        };
      };
    };
  };

  public query ({caller}) func account_balance() : async Types.Tokens {
    Option.get(account_get(caller), Types.zeroToken)
  };

  public query func list_accounts() : async [Types.Account]{
    Iter.toArray(
      Iter.map(Trie.iter(accounts)),
      func ((owner: Principal, tokens:Types.Tokens)) Types.Account = {owner; tokens}
    );
  };

};