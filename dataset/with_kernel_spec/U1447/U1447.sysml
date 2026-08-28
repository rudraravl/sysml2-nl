package MarineChronometer {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    item def WindSignal;
    item def StartSignal;
    
    requirement def MarineChronometerReq {
        doc /* This model describes a high-precision mechanical marine chronometer, a specialized timepiece designed for accurate navigation at sea by enabling the determination of longitude. */
    }
    
    requirement def PowerReserveReq {
        doc /* The mainspring stores a significant power reserve, typically lasting over two days. */
        attribute minReserve : ISQ::DurationValue = 48 [h];
    }
    
    requirement def TorqueEqualizationReq {
        doc /* The fusee equalizes the torque delivered to the rest of the mechanism. */
    }
    
    requirement def OscillatorReq {
        doc /* The balance wheel and hairspring oscillate at a precise frequency. */
    }
    
    requirement def TempCompensationReq {
        doc /* The bimetallic compensator counteracts temperature effects. */
    }
    
    requirement def GimbalIsolationReq {
        doc /* The gimbal mount keeps the chronometer level and isolates it from ship motion. */
    }
    
    requirement def OperationalCycleReq {
        doc /* The chronometer operates in distinct states: Wound, Running, Depleted. */
    }
    
    part def Mainspring {
        attribute powerReserve : ISQ::DurationValue := 48 [h];
        out torque : ISQ::TorqueValue;
    }
    
    part def Fusee {
        in torqueIn : ISQ::TorqueValue;
        out torqueOut : ISQ::TorqueValue;
    }
    
    part def GearTrain {
        in torqueIn : ISQ::TorqueValue;
        out hourHandPosition : ISQ::PlaneAngleValue;
        out minuteHandPosition : ISQ::PlaneAngleValue;
        out secondHandPosition : ISQ::PlaneAngleValue;
    }
    
    part def Dial {
        in hourHandPosition : ISQ::PlaneAngleValue;
        in minuteHandPosition : ISQ::PlaneAngleValue;
        in secondHandPosition : ISQ::PlaneAngleValue;
    }
    
    part def BalanceWheel {
        out oscillation : ISQ::FrequencyValue;
    }
    
    part def Hairspring {
        in temperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    part def DetentEscapement {
        in torqueIn : ISQ::TorqueValue;
        in oscillation : ISQ::FrequencyValue;
        out torqueOut : ISQ::TorqueValue;
    }
    
    part def BimetallicCompensator {
        in temperature : ISQ::ThermodynamicTemperatureValue;
        out compensation : ISQ::TorqueValue;
    }
    
    part def GimbalMount {
        in shipMotion : ISQ::PlaneAngleValue;
        out leveledPosition : ISQ::PlaneAngleValue;
    }
    
    state def ChronometerStates {
        state Wound;
        state Running;
        state Depleted;
        
        transition from Wound to Running accept StartSignal;
        transition from Running to Depleted after 48 [h];
        transition from Depleted to Wound accept WindSignal;
    }
    
    part def Chronometer {
        in ambientTemperature : ISQ::ThermodynamicTemperatureValue;
        in shipMotion : ISQ::PlaneAngleValue;
        
        part mainspring : Mainspring;
        part fusee : Fusee;
        part gearTrain : GearTrain;
        part dial : Dial;
        part balanceWheel : BalanceWheel;
        part hairspring : Hairspring;
        part detentEscapement : DetentEscapement;
        part bimetallicCompensator : BimetallicCompensator;
        part gimbalMount : GimbalMount;
        
        flow mainspring.torque to fusee.torqueIn;
        flow fusee.torqueOut to detentEscapement.torqueIn;
        flow detentEscapement.torqueOut to gearTrain.torqueIn;
        flow gearTrain.hourHandPosition to dial.hourHandPosition;
        flow gearTrain.minuteHandPosition to dial.minuteHandPosition;
        flow gearTrain.secondHandPosition to dial.secondHandPosition;
        flow balanceWheel.oscillation to detentEscapement.oscillation;
        flow ambientTemperature to hairspring.temperature;
        flow ambientTemperature to bimetallicCompensator.temperature;
        flow shipMotion to gimbalMount.shipMotion;
        
        state chronometerStates : ChronometerStates;
    }
}
