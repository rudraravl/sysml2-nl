package MarineChronometerSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Second :> ISQ::time {
        unit = SI::s;
    }

    attribute def Minute :> ISQ::time {
        unit = SI::min;
    }

    attribute def Hour :> ISQ::time {
        unit = SI::h;
    }

    attribute def DegreeCelsius :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def Millimeter :> ISQ::length {
        unit = SI::mm;
    }

    attribute def Gram :> ISQ::mass {
        unit = SI::g;
    }

    attribute def Joule :> ISQ::energy {
        unit = SI::J;
    }

    attribute def RateError {
        attribute value : Real;
        attribute unit : String = "s/day";
    }

    attribute def ChronometerTime {
        attribute hour : Integer;
        attribute minute : Integer;
        attribute second : Real;
    }

    attribute def LongitudeEstimate {
        attribute degreesEast : Real;
        attribute uncertaintyDegrees : Real;
    }

    item def MechanicalEnergy {
        attribute storedEnergy : Joule;
        attribute torque : Real;
    }

    item def OscillationImpulse {
        attribute impulseEnergy : Joule;
        attribute beatPeriod : Second;
    }

    item def TimeIndication {
        attribute indicatedTime : ChronometerTime;
        attribute rateError : RateError;
        attribute powerReserveRemaining : Hour;
    }

    item def WindingCommand {
        attribute turnsApplied : Integer;
        attribute commandTime : ChronometerTime;
    }

    item def TemperatureCondition {
        attribute ambientTemperature : DegreeCelsius;
        attribute temperatureRateOfChange : Real;
    }

    item def ShipMotionCondition {
        attribute rollAngle : Real;
        attribute pitchAngle : Real;
        attribute vibrationLevel : Real;
    }

    port def WindingPort {
        in item windingCommand : WindingCommand;
        out item mainspringEnergy : MechanicalEnergy;
    }

    port def EnergyPort {
        in item energyIn : MechanicalEnergy;
        out item energyOut : MechanicalEnergy;
    }

    port def ImpulsePort {
        in item energyIn : MechanicalEnergy;
        out item impulseOut : OscillationImpulse;
    }

    port def RegulationPort {
        in item impulseIn : OscillationImpulse;
        out item regulatedBeat : OscillationImpulse;
    }

    port def IndicationPort {
        in item regulatedBeat : OscillationImpulse;
        out item timeIndication : TimeIndication;
    }

    port def EnvironmentPort {
        in item temperature : TemperatureCondition;
        in item motion : ShipMotionCondition;
    }

    part def MarineChronometer {
        attribute serialNumber : String;
        attribute nominalBeatPeriod : Second = 0.5 [SI::s];
        attribute ratedDailyError : RateError;
        attribute powerReserveCapacity : Hour = 56 [SI::h];
        attribute currentPowerReserve : Hour;
        attribute caseDiameter : Millimeter = 125 [SI::mm];
        attribute mass : Gram = 2500 [SI::g];
        attribute isRunning : Boolean;
        attribute isLockedForTransport : Boolean;

        port windingInterface : WindingPort;
        port environmentInterface : EnvironmentPort;
        port indicationInterface : IndicationPort;

        part gimballedCase : GimballedCase;
        part windingKey : WindingKey;
        part mainspringBarrel : MainspringBarrel;
        part fuseeChainTransmission : FuseeChainTransmission;
        part chronometerEscapement : ChronometerEscapement;
        part balanceAssembly : CompensationBalanceAssembly;
        part gearTrain : GoingGearTrain;
        part dialAndHands : DialAndHands;
        part rateRegulator : RateRegulator;

        connect windingInterface.mainspringEnergy to mainspringBarrel.energyInput;
        connect mainspringBarrel.energyOutput to fuseeChainTransmission.energyInput;
        connect fuseeChainTransmission.energyOutput to chronometerEscapement.energyInput;
        connect chronometerEscapement.impulseOutput to balanceAssembly.impulseInput;
        connect balanceAssembly.regulatedBeatOutput to gearTrain.regulationInput;
        connect gearTrain.indicationOutput to dialAndHands.indicationInput;
        connect dialAndHands.timeOutput to indicationInterface.timeIndication;

        connect environmentInterface.temperature to balanceAssembly.thermalInput;
        connect environmentInterface.motion to gimballedCase.motionInput;
        connect gimballedCase.stabilizedMotionOutput to balanceAssembly.motionInput;

        perform action keepReferenceTime;
        exhibit state chronometerOperatingState;
    }

    part def GimballedCase {
        attribute allowableRollCompensation : Real = 45.0;
        attribute allowablePitchCompensation : Real = 45.0;
        attribute deckMountLocked : Boolean;

        port motionInput {
            in item motion : ShipMotionCondition;
        }

        port stabilizedMotionOutput {
            out item motion : ShipMotionCondition;
        }
    }

    part def WindingKey {
        attribute removable : Boolean = true;
        attribute maximumSafeTurns : Integer = 12;

        port windingOutput : WindingPort;
    }

    part def MainspringBarrel {
        attribute storedEnergy : Joule;
        attribute maximumStoredEnergy : Joule = 18.0 [SI::J];
        attribute minimumOperatingEnergy : Joule = 2.0 [SI::J];
        attribute arborFrictionCoefficient : Real;

        port energyInput {
            in item energyInput : MechanicalEnergy;
        }

        port energyOutput : EnergyPort;
    }

    part def FuseeChainTransmission {
        attribute torqueEqualizationRatio : Real;
        attribute chainTension : Real;
        attribute outputTorqueRipple : Real;

        port energyInput : EnergyPort;
        port energyOutput : EnergyPort;
    }

    part def ChronometerEscapement {
        attribute escapementType : String = "spring detent";
        attribute lockingAngle : Real;
        attribute impulseEfficiency : Real;
        attribute escapeWheelToothCount : Integer = 15;

        port energyInput : EnergyPort;
        port impulseOutput : ImpulsePort;
    }

    part def CompensationBalanceAssembly {
        attribute balanceDiameter : Millimeter = 30 [SI::mm];
        attribute hairspringStiffness : Real;
        attribute thermalCompensationError : RateError;
        attribute positionalError : RateError;
        attribute beatPeriod : Second = 0.5 [SI::s];

        port impulseInput : ImpulsePort;
        port regulatedBeatOutput : RegulationPort;

        port thermalInput {
            in item temperature : TemperatureCondition;
        }

        port motionInput {
            in item motion : ShipMotionCondition;
        }
    }

    part def GoingGearTrain {
        attribute wheelCount : Integer = 5;
        attribute totalGearRatio : Real = 43200.0;
        attribute frictionLoss : Real;
        attribute backlash : Real;

        port regulationInput : RegulationPort;
        port indicationOutput : IndicationPort;
    }

    part def DialAndHands {
        attribute dialMarkingStyle : String = "24 hour subsidiary seconds";
        attribute handReadabilityArcMinutes : Real;
        attribute luminousMarking : Boolean = false;

        port indicationInput : IndicationPort;

        port timeOutput {
            out item timeIndication : TimeIndication;
        }
    }

    part def RateRegulator {
        attribute adjustableRange : RateError;
        attribute currentCorrection : RateError;
        attribute calibrationIntervalDays : Integer = 30;
    }

    action def WindChronometer {
        in item command : WindingCommand;
        inout part barrel : MainspringBarrel;
        out item storedEnergy : MechanicalEnergy;

        first start;
        then validateTurns;
        then addEnergy;
        then limitToSafeCapacity;
        then complete;

        action validateTurns {
            assert command.turnsApplied >= 0;
            assert command.turnsApplied <= 12;
        }

        action addEnergy {
            storedEnergy.storedEnergy = barrel.storedEnergy + command.turnsApplied * 1.5 [SI::J];
        }

        action limitToSafeCapacity {
            if storedEnergy.storedEnergy > barrel.maximumStoredEnergy then
                storedEnergy.storedEnergy = barrel.maximumStoredEnergy;
            end;
        }
    }

    action def KeepReferenceTime {
        in item temperature : TemperatureCondition;
        in item motion : ShipMotionCondition;
        in item winding : WindingCommand;
        out item indicatedTime : TimeIndication;
        out item longitudeSupport : LongitudeEstimate;

        part chronometer : MarineChronometer;

        first receiveWinding;
        then storeEnergy;
        then equalizeTorque;
        then releaseEscapementImpulse;
        then sustainBalanceOscillation;
        then countOscillations;
        then displayTime;
        then supportLongitudeCalculation;

        action receiveWinding : WindChronometer {
            in command = winding;
            inout barrel = chronometer.mainspringBarrel;
        }

        action storeEnergy {
            chronometer.currentPowerReserve =
                chronometer.powerReserveCapacity *
                chronometer.mainspringBarrel.storedEnergy /
                chronometer.mainspringBarrel.maximumStoredEnergy;
        }

        action equalizeTorque {
            chronometer.fuseeChainTransmission.outputTorqueRipple <= 0.03;
        }

        action releaseEscapementImpulse {
            chronometer.chronometerEscapement.impulseEfficiency >= 0.70;
        }

        action sustainBalanceOscillation {
            chronometer.balanceAssembly.beatPeriod = chronometer.nominalBeatPeriod;
        }

        action countOscillations {
            indicatedTime.powerReserveRemaining = chronometer.currentPowerReserve;
            indicatedTime.rateError = chronometer.ratedDailyError;
        }

        action displayTime {
            indicatedTime.indicatedTime.hour >= 0;
            indicatedTime.indicatedTime.hour < 24;
            indicatedTime.indicatedTime.minute >= 0;
            indicatedTime.indicatedTime.minute < 60;
            indicatedTime.indicatedTime.second >= 0.0;
            indicatedTime.indicatedTime.second < 60.0;
        }

        action supportLongitudeCalculation {
            longitudeSupport.degreesEast =
                15.0 * (indicatedTime.indicatedTime.hour
                + indicatedTime.indicatedTime.minute / 60.0
                + indicatedTime.indicatedTime.second / 3600.0);
            longitudeSupport.uncertaintyDegrees =
                abs(indicatedTime.rateError.value) * 15.0 / 3600.0;
        }
    }

    state def ChronometerOperatingState {
        entry action initialize {
            isRunning = false;
            isLockedForTransport = false;
        }

        state stopped;
        state wound;
        state running;
        state lowPower;
        state transportLocked;
        state calibrationRequired;

        initial then stopped;

        transition stopped_to_wound
            first stopped
            accept WindingCommand
            if currentPowerReserve > 0 [SI::h]
            then wound;

        transition wound_to_running
            first wound
            if isLockedForTransport == false
            do startOscillation
            then running;

        transition running_to_lowPower
            first running
            if currentPowerReserve <= 6 [SI::h]
            then lowPower;

        transition lowPower_to_running
            first lowPower
            accept WindingCommand
            if currentPowerReserve > 6 [SI::h]
            then running;

        transition running_to_calibrationRequired
            first running
            if abs(ratedDailyError.value) > 1.0
            then calibrationRequired;

        transition calibrationRequired_to_running
            first calibrationRequired
            do regulateRate
            if abs(ratedDailyError.value) <= 1.0
            then running;

        transition running_to_transportLocked
            first running
            if isLockedForTransport == true
            then transportLocked;

        transition transportLocked_to_stopped
            first transportLocked
            do stopBalance
            then stopped;

        action startOscillation {
            isRunning = true;
        }

        action regulateRate {
            rateRegulator.currentCorrection.value = -ratedDailyError.value;
            ratedDailyError.value = 0.0;
        }

        action stopBalance {
            isRunning = false;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The marine chronometer shall provide a stable, portable reference time
         * aboard a vessel so that navigators can compare local apparent noon with
         * reference time and determine longitude.
         */

        subject chronometer : MarineChronometer;

        require constraint {
            chronometer.isRunning implies
            abs(chronometer.ratedDailyError.value) <= 2.0
        }
    }

    requirement def PowerReserveRequirement {
        doc
        /*
         * The chronometer shall continue indicating reference time for at least
         * forty eight hours after full winding.
         */

        subject chronometer : MarineChronometer;

        require constraint {
            chronometer.powerReserveCapacity >= 48 [SI::h]
        }
    }

    requirement def ShipboardStabilityRequirement {
        doc
        /*
         * The chronometer shall maintain timekeeping operation under ordinary
         * shipboard roll, pitch, and vibration by isolating the movement with
         * a gimballed case.
         */

        subject chronometer : MarineChronometer;

        require constraint {
            chronometer.gimballedCase.allowableRollCompensation >= 30.0 and
            chronometer.gimballedCase.allowablePitchCompensation >= 30.0
        }
    }

    requirement def TemperatureCompensationRequirement {
        doc
        /*
         * The balance assembly shall compensate rate variation over the expected
         * cabin temperature range.
         */

        subject balance : CompensationBalanceAssembly;

        require constraint {
            abs(balance.thermalCompensationError.value) <= 1.5
        }
    }

    requirement def ReadabilityRequirement {
        doc
        /*
         * The indicated reference time shall be readable by an operator without
         * opening the chronometer case.
         */

        subject display : DialAndHands;

        require constraint {
            display.handReadabilityArcMinutes <= 2.0
        }
    }

    requirement def SafeWindingRequirement {
        doc
        /*
         * Winding shall store energy without exceeding the safe mainspring energy
         * capacity.
         */

        subject barrel : MainspringBarrel;

        require constraint {
            barrel.storedEnergy <= barrel.maximumStoredEnergy
        }
    }

    satisfy PrimaryFunctionRequirement by MarineChronometer;
    satisfy PowerReserveRequirement by MarineChronometer;
    satisfy ShipboardStabilityRequirement by MarineChronometer;
    satisfy TemperatureCompensationRequirement by CompensationBalanceAssembly;
    satisfy ReadabilityRequirement by DialAndHands;
    satisfy SafeWindingRequirement by MainspringBarrel;

    part marineNavigationChronometer : MarineChronometer {
        serialNumber = "MC-1847-REFERENCE";
        ratedDailyError.value = 0.8;
        ratedDailyError.unit = "s/day";
        currentPowerReserve = 56 [SI::h];
        isRunning = true;
        isLockedForTransport = false;

        part gimballedCase {
            allowableRollCompensation = 45.0;
            allowablePitchCompensation = 45.0;
            deckMountLocked = true;
        }

        part mainspringBarrel {
            storedEnergy = 18.0 [SI::J];
            maximumStoredEnergy = 18.0 [SI::J];
            minimumOperatingEnergy = 2.0 [SI::J];
            arborFrictionCoefficient = 0.015;
        }

        part fuseeChainTransmission {
            torqueEqualizationRatio = 0.97;
            chainTension = 12.0;
            outputTorqueRipple = 0.02;
        }

        part chronometerEscapement {
            lockingAngle = 2.0;
            impulseEfficiency = 0.76;
            escapeWheelToothCount = 15;
        }

        part balanceAssembly {
            balanceDiameter = 30 [SI::mm];
            hairspringStiffness = 0.00012;
            beatPeriod = 0.5 [SI::s];
            thermalCompensationError.value = 0.7;
            thermalCompensationError.unit = "s/day";
            positionalError.value = 0.5;
            positionalError.unit = "s/day";
        }

        part gearTrain {
            wheelCount = 5;
            totalGearRatio = 43200.0;
            frictionLoss = 0.08;
            backlash = 0.01;
        }

        part dialAndHands {
            dialMarkingStyle = "Roman hour chapter with subsidiary seconds";
            handReadabilityArcMinutes = 1.5;
            luminousMarking = false;
        }

        part rateRegulator {
            adjustableRange.value = 8.0;
            adjustableRange.unit = "s/day";
            currentCorrection.value = 0.0;
            currentCorrection.unit = "s/day";
            calibrationIntervalDays = 30;
        }
    }
}