pragma solidity >=0.6.8;
pragma experimental ABIEncoderV2;
// SPDX-License-Identifier: MIT
import "./token/BEP20/BEP20Token.sol";
import './math/UInt256Lib.sol';
import "./Initializable.sol";
import "./ownership/Ownable.sol";
import "./math/SafeMath.sol";
import "./math/SafeMathInt.sol";
import "./eBNBMoney.sol";
import "../oracle/Bandprotocol.sol";


interface IOracle {
    function getData() external returns (uint256, bool);
}

contract eBNBPolicy is OwnableUpgradeSafe{
    IStdReference internal ref;
    uint256 public price;

    using SafeMath for uint256;
    using SafeMathInt for int256;
    using UInt256Lib for uint256;

    event LogRebase(
        uint256 indexed epoch,
        uint256 exchangeRate,
        uint256 cpi,
        int256 requestedSupplyAdjustment,
        uint256 timestampSec        
    );    

       
        eBNB public uFrags;
       
       

        // Provides the current CPI, as an 18 decimal fixed point number.
        IOracle public cpiOracle;

        // Market oracle provides the token/USD exchange rate as an 18 decimal fixed point number.
        // (eg) An oracle value of 1.5e18 it would mean 1 Ample is trading for $1.50.
        IOracle public marketOracle;

        // CPI value at the time of launch, as an 18 decimal fixed point number.
        uint256 private baseCpi;

        // If the current exchange rate is within this fractional distance from the target, no supply
        // update is performed. Fixed point number--same format as the rate.
        // (ie) abs(rate - targetRate) / targetRate < deviationThreshold, then no supply change.
        // DECIMALS Fixed point number.
        uint256 public deviationThreshold;

        // The rebase lag parameter, used to dampen the applied supply adjustment by 1 / rebaseLag
        // Check setRebaseLag comments for more details.
        // Natural number, no decimal places.
        uint256 public rebaseLag;
        uint256 public supplyAfterRebase;
        uint256 public exchangeRate;

        // More than this much time must pass between rebase operations.
        uint256 public minRebaseTimeIntervalSec;

        // Block timestamp of last rebase operation
        uint256 public lastRebaseTimestampSec;

        // The rebase window begins this many seconds into the minRebaseTimeInterval period.
        // For example if minRebaseTimeInterval is 24hrs, it represents the time of day in seconds.
        uint256 public rebaseWindowOffsetSec;

        // The length of the time window where a rebase operation is allowed to execute, in seconds.
        uint256 public rebaseWindowLengthSec;

        // The number of rebase cycles since inception
        uint256 public epoch;

        uint256 private constant DECIMALS = 18;
       

        // Due to the expression in computeSupplyDelta(), MAX_RATE * MAX_SUPPLY must fit into an int256.
        // Both are 18 decimals fixed point numbers.
        uint256 private constant MAX_RATE = 10**6 * 10**DECIMALS;
        // MAX_SUPPLY = MAX_INT256 / MAX_RATE
        uint256 public constant MAX_SUPPLY = ~(uint256(1) << 255) / MAX_RATE;

        // This module eBNBorchestrates the rebase execution and downstream notification.
        address public orchestrator;

        modifier onlyOrchestrator() {
            require(msg.sender == orchestrator);
            _;
        }

        /**
        * @notice Initiates a new rebase operation, provided the minimum time period has elapsed.
        *
        * @dev The supply adjustment equals (_totalSupply * DeviationFromTargetRate) / rebaseLag
        *      Where DeviationFromTargetRate is (MarketOracleRate - targetRate) / targetRate
        *      and targetRate is CpiOracleRate / baseCpi
        */
        function getPrice() external payable  returns (uint256){
        IStdReference.ReferenceData memory data = ref.getReferenceData("BNB","USD");
        price =data.rate;
        return price;
    }
         
       
     
        function rebase() external  {
            //require(inRebaseWindow());

            // This comparison also ensures there is no reentrancy.
           // require(lastRebaseTimestampSec.add(minRebaseTimeIntervalSec) < block.timestamp);

            // Snap the rebase time to the start of this window.
            //lastRebaseTimestampSec = block.timestamp.sub(
                //block.timestamp.mod(minRebaseTimeIntervalSec)).add(rebaseWindowOffsetSec);

            epoch = epoch.add(1);

            uint256 cpi = 1;
            bool cpiValid = true;
            //(cpi, cpiValid) = cpiOracle.getData();
            require(cpiValid);

            uint256 targetRate = cpi.mul(10 ** DECIMALS);

            //uint256 exchangeRate = 20000000000000000;
           
       
            bool rateValid = true;
            //(exchangeRate, rateValid) = marketOracle.getData();
            require(rateValid);
            exchangeRate = price;


            if (exchangeRate > MAX_RATE) {
                exchangeRate = MAX_RATE;
            }

            int256 supplyDelta = computeSupplyDelta(exchangeRate, targetRate);
           
            // Apply the Dampening factor.
            supplyDelta = supplyDelta.div(rebaseLag.toInt256Safe());

            if (supplyDelta > 0 && uFrags.totalSupply().add(uint256(supplyDelta)) > MAX_SUPPLY) {
                supplyDelta = (MAX_SUPPLY.sub(uFrags.totalSupply())).toInt256Safe();
            }

            supplyAfterRebase = uFrags.rebase(epoch, supplyDelta);
            assert(supplyAfterRebase <= MAX_SUPPLY);
            emit LogRebase(epoch, exchangeRate, targetRate, supplyDelta, block.timestamp);
           
           
        }

        /**
        * @notice Sets the reference to the CPI oracle.
        * @param cpiOracle_ The address of the cpi oracle contract.
        */
      function setCpiOracle(IOracle cpiOracle_)
            external
            onlyOwner
        {
            cpiOracle = cpiOracle_;
        }

        /**
        * @notice Sets the reference to the market oracle.
        * @param marketOracle_ The address of the market oracle contract.
        */
        function setMarketOracle(IOracle marketOracle_)
            external
            onlyOwner
        {
            marketOracle = marketOracle_;
        }

        /**
        * @notice Sets the reference to the eBNBorchestrator.
        * @param orchestrator_ The address of the eBNBorchestrator contract.
        */
        function setOrchestrator(address orchestrator_)
            external
            onlyOwner
        {
            orchestrator = orchestrator_;
        }

        /**
        * @notice Sets the deviation threshold fraction. If the exchange rate given by the market
        *         oracle is within this fractional distance from the targetRate, then no supply
        *         modifications are made. DECIMALS fixed point number.
        * @param deviationThreshold_ The new exchange rate threshold fraction.
        */
        function setDeviationThreshold(uint256 deviationThreshold_)
            external
            onlyOwner
        {
            deviationThreshold = deviationThreshold_;
        }

        /**
        * @notice Sets the rebase lag parameter.
                It is used to dampen the applied supply adjustment by 1 / rebaseLag
                If the rebase lag R, equals 1, the smallest value for R, then the full supply
                correction is applied on each rebase cycle.
                If it is greater than 1, then a correction of 1/R of is applied on each rebase.
        * @param rebaseLag_ The new rebase lag parameter.
        */
       function setRebaseLag(uint256 rebaseLag_)
            external
            onlyOwner
        {
            require(rebaseLag_ > 0);
            rebaseLag = rebaseLag_;
        }

        /**
        * @notice Sets the parameters which control the timing and frequency of
        *         rebase operations.
        *         a) the minimum time period that must elapse between rebase cycles.
        *         b) the rebase window offset parameter.
        *         c) the rebase window length parameter.
        * @param minRebaseTimeIntervalSec_ More than this much time must pass between rebase
        *        operations, in seconds.
        * @param rebaseWindowOffsetSec_ The number of seconds from the beginning of
                the rebase interval, where the rebase window begins.
        * @param rebaseWindowLengthSec_ The length of the rebase window in seconds.
        */
         function setRebaseTimingParameters(
            uint256 minRebaseTimeIntervalSec_,
            uint256 rebaseWindowOffsetSec_,
            uint256 rebaseWindowLengthSec_)
            external
            onlyOwner
        {
            require(minRebaseTimeIntervalSec_ > 0);
            require(rebaseWindowOffsetSec_ < minRebaseTimeIntervalSec_);

            minRebaseTimeIntervalSec = minRebaseTimeIntervalSec_;
            rebaseWindowOffsetSec = rebaseWindowOffsetSec_;
            rebaseWindowLengthSec = rebaseWindowLengthSec_;
        }

        /**
        * @dev ZOS upgradable contract initialization method.
        *      It is called at the time of contract creation to invoke parent class initializers and
        *      initialize the contract's state variables.
        */
       function initialize(eBNB uFrags_,IStdReference _ref)
            public
            initializer
        {
            OwnableUpgradeSafe.__Ownable_init();


            // deviationThreshold = 0.05e18 = 5e16
            deviationThreshold = 5 * 10 ** (DECIMALS-2);

            rebaseLag = 50;
            minRebaseTimeIntervalSec = 2 days;
            rebaseWindowOffsetSec = 60 minutes;  // 8PM UTC
            rebaseWindowLengthSec = 4 hours;
            lastRebaseTimestampSec = 0;
            epoch = 0;

            uFrags = uFrags_;
            ref = _ref;
           
        }

        /**
        * @return If the latest block timestamp is within the rebase time window it, returns true.
        *         Otherwise, returns false.
        */
        function inRebaseWindow() public view returns (bool) {
            return (
                block.timestamp.mod(minRebaseTimeIntervalSec) >= rebaseWindowOffsetSec &&
                block.timestamp.mod(minRebaseTimeIntervalSec) < (rebaseWindowOffsetSec.add(rebaseWindowLengthSec))
            );
        }

        /**
        * @return Computes the total supply adjustment in response to the exchange rate
        *         and the targetRate.
        */
        function computeSupplyDelta(uint256 rate, uint256 targetRate)
            public
            view
            returns (int256)
        {
            if (withinDeviationThreshold(rate, targetRate)) {
                return 0;
            }

            // supplyDelta = totalSupply * (rate - targetRate) / targetRate
            int256 targetRateSigned = targetRate.toInt256Safe();
            return  uFrags.totalSupply().toInt256Safe()
                .mul(rate.toInt256Safe().sub(targetRateSigned))
                .div(targetRateSigned);
        }

        /**
        * @param rate The current exchange rate, an 18 decimal fixed point number.
        * @param targetRate The target exchange rate, an 18 decimal fixed point number.
        * @return If the rate is within the deviation threshold from the target rate, returns true.
        *         Otherwise, returns false.
        */
       function withinDeviationThreshold(uint256 rate, uint256 targetRate)
            private
            view
            returns (bool)
        {
            uint256 absoluteDeviationThreshold = targetRate.mul(deviationThreshold)
                .div(10 ** DECIMALS);

            return (rate >= targetRate && rate.sub(targetRate) < absoluteDeviationThreshold)
                || (rate < targetRate && targetRate.sub(rate) < absoluteDeviationThreshold);
        }
    }