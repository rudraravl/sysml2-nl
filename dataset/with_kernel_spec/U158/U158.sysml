package BairHuggerWarmingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    public import Definitions::*;
    
    package Definitions {
        private import ScalarValues::*;
        private import ISQ::*;
        private import SI::*;
        
        attribute def TemperatureValue :> ISQ::temperature;
        attribute def PowerValue :> ISQ::power;
        
        item def Air {
            attribute temperature :> TemperatureValue;
            attribute flowRate :> ScalarValues::Real;
        }
        
        attribute def TargetTemp :> TemperatureValue;
        attribute def HeaterTemp :> TemperatureValue;
        attribute def PatientTemp :> TemperatureValue;
        attribute def HeaterPowerCmd :> PowerValue;
        attribute def BlowerSpeedCmd :> ScalarValues::Real;
        attribute def AlarmSignal;
        attribute def ShutdownCmd;
        attribute def PowerOnSignal;
        attribute def PowerOffSignal;
        attribute def StartWarmingSignal;
        attribute def StopWarmingSignal;
        attribute def SelfTestPassed;
        attribute def SelfTestFailed;
        attribute def ResetSignal;
        
        part def WarmingSystem {
            port alarmPort { in alarm : AlarmSignal; }
            exhibit state 'system states' : SystemStates;
        }
        
        part def WarmingUnit {
            port airInPort { in air : Air; }
            port airOutPort { out air : Air; }
            port heaterCmdPort { in heaterCmd : HeaterPowerCmd; }
            port blowerCmdPort { in blowerCmd : BlowerSpeedCmd; }
            port powerPort { in power : PowerValue; }
            part airFilter : AirFilter;
            part blower : Blower;
            part heatingElement : HeatingElement;
            bind airInPort = airFilter.airInPort;
            bind airOutPort = heatingElement.airOutPort;
            bind heaterCmdPort = heatingElement.cmdPort;
            bind blowerCmdPort = blower.cmdPort;
        }
        
        part def AirFilter {
            port airInPort { in air : Air; }
            port airOutPort { out air : Air; }
            perform action 'filter air': 'Filter Air';
        }
        
        part def Blower {
            port airInPort { in air : Air; }
            port airOutPort { out air : Air; }
            port cmdPort { in blowerCmd : BlowerSpeedCmd; }
            perform action 'blow air': 'Blow Air';
        }
        
        part def HeatingElement {
            port airInPort { in air : Air; }
            port airOutPort { out air : Air; }
            port cmdPort { in heaterCmd : HeaterPowerCmd; }
            port tempSensePort { out heaterTemp : HeaterTemp; }
            perform action 'heat air': 'Heat Air';
            perform action 'sense heater temp': 'Sense Heater Temp';
        }
        
        part def DeliveryHose {
            port airInPort { in air : Air; }
            port airOutPort { out air : Air; }
        }
        
        part def WarmingBlanket {
            port airInPort { in air : Air; }
            port patientTempPort { out patientTemp : PatientTemp; }
            perform action 'distribute air': 'Distribute Air';
            perform action 'sense patient temp': 'Sense Patient Temp';
        }
        
        part def ControlModule {
            port targetTempPort { in targetTemp : TargetTemp; }
            port heaterTempPort { in heaterTemp : HeaterTemp; }
            port patientTempPort { in patientTemp : PatientTemp; }
            port heaterCmdPort { out heaterCmd : HeaterPowerCmd; }
            port blowerCmdPort { out blowerCmd : BlowerSpeedCmd; }
            port shutdownPort { in shutdown : ShutdownCmd; }
            port powerPort { in power : PowerValue; }
            perform action 'control temperature': 'Control Temperature';
        }
        
        part def SafetyMonitor {
            port heaterTempPort { in heaterTemp : HeaterTemp; }
            port shutdownPort { out shutdown : ShutdownCmd; }
            port alarmPort { out alarm : AlarmSignal; }
            port powerPort { in power : PowerValue; }
            perform action 'monitor safety': 'Monitor Safety';
        }
        
        part def UserInterface {
            port targetTempPort { out targetTemp : TargetTemp; }
            port powerPort { in power : PowerValue; }
        }
        
        part def PowerSupply {
            port acInPort { in acPower : PowerValue; }
            port dcOutPort { out dcPower : PowerValue; }
            perform action 'convert power': 'Convert Power';
        }
        
        part def Environment {
            port airOutPort { out air : Air; }
        }
        
        part def WallOutlet {
            port powerOutPort { out power : PowerValue; }
        }
        
        action def 'Filter Air' {
            in ambientAir : Air;
            out filteredAir : Air;
        }
        action def 'Blow Air' {
            in filteredAir : Air;
            in speedCmd : BlowerSpeedCmd;
            out pressurizedAir : Air;
        }
        action def 'Heat Air' {
            in pressurizedAir : Air;
            in powerCmd : HeaterPowerCmd;
            out heatedAir : Air;
        }
        action def 'Sense Heater Temp' {
            out heaterTemp : HeaterTemp;
        }
        action def 'Distribute Air' {
            in heatedAir : Air;
        }
        action def 'Sense Patient Temp' {
            out patientTemp : PatientTemp;
        }
        action def 'Control Temperature' {
            in targetTemp : TargetTemp;
            in heaterTemp : HeaterTemp;
            in patientTemp : PatientTemp;
            out heaterCmd : HeaterPowerCmd;
            out blowerCmd : BlowerSpeedCmd;
        }
        action def 'Monitor Safety' {
            in heaterTemp : HeaterTemp;
            out shutdown : ShutdownCmd;
            out alarm : AlarmSignal;
        }
        action def 'Convert Power' {
            in acPower : PowerValue;
            out dcPower : PowerValue;
        }
        action def 'Perform Self Test';
        action def 'Sound Alarm';
        action def 'Warming Operation';
        
        state def SystemStates {
            action 'perform self test': 'Perform Self Test';
            action 'sound alarm': 'Sound Alarm';
            action 'warming operation': 'Warming Operation';
            
            entry; then 'power off';
            state 'power off';
            transition 'off_to_standby'
                first 'power off'
                accept PowerOnSignal
                then standby;
            state standby {
                entry 'perform self test';
            }
            transition 'standby_to_ready'
                first standby
                accept SelfTestPassed
                then ready;
            transition 'standby_to_alarm'
                first standby
                accept SelfTestFailed
                then alarm;
            state ready;
            transition 'ready_to_warming'
                first ready
                accept StartWarmingSignal
                then warming;
            state warming {
                do 'warming operation';
            }
            transition 'warming_to_ready'
                first warming
                accept StopWarmingSignal
                then ready;
            transition 'warming_to_alarm'
                first warming
                accept AlarmSignal
                then alarm;
            state alarm {
                entry 'sound alarm';
            }
            transition 'alarm_to_ready'
                first alarm
                accept ResetSignal
                then ready;
            transition 'alarm_to_off'
                first alarm
                accept PowerOffSignal
                then 'power off';
            transition 'ready_to_off'
                first ready
                accept PowerOffSignal
                then 'power off';
        }
        
        requirement def 'Maintain Patient Temperature' {
            doc /* The system shall maintain the patient body temperature within 0.5 K of the clinician-set target. */
            attribute targetTemp : TemperatureValue;
            attribute patientTemp : TemperatureValue;
            constraint { patientTemp >= targetTemp - 0.5 [K] and patientTemp <= targetTemp + 0.5 [K] }
        }
        requirement def 'Maximum Air Temperature' {
            doc /* The air temperature delivered to the blanket shall not exceed 43 degrees Celsius under normal operation. */
            attribute deliveredAirTemp : TemperatureValue;
            constraint { deliveredAirTemp <= 316.15 [K] }
        }
        requirement def 'Safety Shutoff' {
            doc /* The safety monitor shall trigger a system shutdown if the heater air temperature exceeds 45 degrees Celsius. */
            attribute heaterTemp : TemperatureValue;
            attribute shutdownTriggered : Boolean;
            constraint { heaterTemp > 318.15 [K] implies shutdownTriggered }
        }
        requirement def 'Air Filtration' {
            doc /* The system shall filter incoming ambient air to a minimum efficiency of 99.97 percent for particles 0.3 micrometers and larger. */
        }
        requirement def 'Self Test on Power On' {
            doc /* The system shall perform a self-test upon power-on and only transition to ready state if all components pass. */
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part environment : Environment;
        part wallOutlet : WallOutlet;
        
        part bairHugger : WarmingSystem {
            part powerSupply : PowerSupply;
            part warmingUnit : WarmingUnit;
            part deliveryHose : DeliveryHose;
            part warmingBlanket : WarmingBlanket;
            part controlModule : ControlModule;
            part userInterface : UserInterface;
            part safetyMonitor : SafetyMonitor;
            
            flow acPowerFlow of PowerValue from wallOutlet.powerOutPort.power to powerSupply.acInPort.acPower;
            flow dcPowerToUnit of PowerValue from powerSupply.dcOutPort.dcPower to warmingUnit.powerPort.power;
            flow dcPowerToControl of PowerValue from powerSupply.dcOutPort.dcPower to controlModule.powerPort.power;
            flow dcPowerToSafety of PowerValue from powerSupply.dcOutPort.dcPower to safetyMonitor.powerPort.power;
            flow dcPowerToUI of PowerValue from powerSupply.dcOutPort.dcPower to userInterface.powerPort.power;
            
            flow ambientAirFlow of Air from environment.airOutPort.air to warmingUnit.airInPort.air;
            flow filteredAirFlow of Air from warmingUnit.airFilter.airOutPort.air to warmingUnit.blower.airInPort.air;
            flow blownAirFlow of Air from warmingUnit.blower.airOutPort.air to warmingUnit.heatingElement.airInPort.air;
            flow airToHose of Air from warmingUnit.airOutPort.air to deliveryHose.airInPort.air;
            flow airToBlanket of Air from deliveryHose.airOutPort.air to warmingBlanket.airInPort.air;
            
            flow targetTempFlow of TargetTemp from userInterface.targetTempPort.targetTemp to controlModule.targetTempPort.targetTemp;
            flow heaterTempToControl of HeaterTemp from warmingUnit.heatingElement.tempSensePort.heaterTemp to controlModule.heaterTempPort.heaterTemp;
            flow heaterTempToSafety of HeaterTemp from warmingUnit.heatingElement.tempSensePort.heaterTemp to safetyMonitor.heaterTempPort.heaterTemp;
            flow patientTempFlow of PatientTemp from warmingBlanket.patientTempPort.patientTemp to controlModule.patientTempPort.patientTemp;
            
            flow heaterCmdFlow of HeaterPowerCmd from controlModule.heaterCmdPort.heaterCmd to warmingUnit.heaterCmdPort.heaterCmd;
            flow blowerCmdFlow of BlowerSpeedCmd from controlModule.blowerCmdPort.blowerCmd to warmingUnit.blowerCmdPort.blowerCmd;
            
            flow shutdownFlow of ShutdownCmd from safetyMonitor.shutdownPort.shutdown to controlModule.shutdownPort.shutdown;
            flow alarmFlow of AlarmSignal from safetyMonitor.alarmPort.alarm to alarmPort.alarm;
        }
        
        requirement 'maintain patient temp' : 'Maintain Patient Temperature' {
            attribute targetTemp = 310.15 [K];
            attribute patientTemp = 310.15 [K];
        }
        requirement 'max air temp' : 'Maximum Air Temperature' {
            attribute deliveredAirTemp = 313.15 [K];
        }
        requirement 'safety shutoff' : 'Safety Shutoff' {
            attribute heaterTemp = 315.15 [K];
            attribute shutdownTriggered = false;
        }
        requirement 'air filtration' : 'Air Filtration';
        requirement 'self test' : 'Self Test on Power On';
    }
}
