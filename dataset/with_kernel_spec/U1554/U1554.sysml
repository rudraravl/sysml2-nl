package EVA_System {
    private import ISQ::*;
    private import ScalarValues::*;
    
    package Items {
        item def Oxygen;
        item def CarbonDioxide;
        item def Coolant;
        item def Nitrogen;
        item def VoiceData;
    }
    
    package Signals {
        item def StartPrebreath;
        item def CompletePrebreath;
        item def Depressurized;
        item def EgressComplete;
        item def MissionComplete;
        item def IngressComplete;
        item def Repressurized;
        item def Warning;
        item def CriticalAlert;
        item def Reset;
    }
    
    package Ports {
        port def OxygenOutPort;
        port def OxygenInPort;
        port def CO2OutPort;
        port def CO2InPort;
        port def CoolantOutPort;
        port def CoolantInPort;
        port def ElectricalPowerPort;
        port def DataPort;
        port def ThrustPort;
    }
    
    package Flows {
        flow def OxygenFlow {
            end port supplier : Ports::OxygenOutPort;
            end port consumer : Ports::OxygenInPort;
        }
        flow def CO2Flow {
            end port supplier : Ports::CO2OutPort;
            end port consumer : Ports::CO2InPort;
        }
        flow def CoolantFlow {
            end port supplier : Ports::CoolantOutPort;
            end port consumer : Ports::CoolantInPort;
        }
        flow def PowerFlow {
            end port supplier : Ports::ElectricalPowerPort;
            end port consumer : Ports::ElectricalPowerPort;
        }
        flow def DataFlow {
            end port supplier : Ports::DataPort;
            end port consumer : Ports::DataPort;
        }
    }
    
    package Parts {
        private import Signals::*;
        
        part def PLSS {
            port oxygenOut : Ports::OxygenOutPort;
            port co2In : Ports::CO2InPort;
            port coolantOut : Ports::CoolantOutPort;
            port coolantInReturn : Ports::CoolantInPort;
            port powerOut : Ports::ElectricalPowerPort;
            
            part oxygenTank {
                attribute capacity :> ISQ::volume;
            }
            part co2Filter;
            part battery {
                attribute charge :> ISQ::energy;
            }
            part coolingSystem;
        }
        
        part def ThermalMicrometeoroidGarment;
        
        part def PressureGarmentAssembly {
            port oxygenIn : Ports::OxygenInPort;
            port co2Out : Ports::CO2OutPort;
            port coolantIn : Ports::CoolantInPort;
            port coolantReturn : Ports::CoolantOutPort;
            
            part pressureLayer;
            part restraintLayer;
            part tmg : ThermalMicrometeoroidGarment;
        }
        
        part def HelmetAndVisorAssembly {
            port oxygenIn : Ports::OxygenInPort;
            part polycarbonateShell;
            part goldVisor;
            part ventilationSystem;
        }
        
        part def ExtravehicularGloves {
            port powerIn : Ports::ElectricalPowerPort;
            part heaters;
        }
        
        part def CommunicationCarrierAssembly {
            port dataOut : Ports::DataPort;
            part microphone;
            part speaker;
            part radioTransceiver;
        }
        
        part def DisplayAndControlModule {
            port powerIn : Ports::ElectricalPowerPort;
            port dataIn : Ports::DataPort;
            attribute oxygenLevel :> ISQ::volume;
            attribute batteryLevel :> ISQ::energy;
        }
        
        part def SafetyTether;
        
        part def SAFER {
            port thrustPort : Ports::ThrustPort;
            part nitrogenThrusters;
        }
        
        part def EMU {
            attribute mass :> ISQ::mass;
            attribute powerConsumption :> ISQ::power;
            
            port oxygenSupplyPort : Ports::OxygenOutPort;
            port dataPort : Ports::DataPort;
            
            exhibit state evaMission {
                entry action initial;
                state standby;
                state prebreathing;
                state depressurization;
                state egress;
                state operations;
                state ingress;
                state repressurization;
                
                transition initial then standby;
                transition standby_to_prebreathing
                    first standby
                    accept StartPrebreath
                    then prebreathing;
                transition prebreathing_to_depressurization
                    first prebreathing
                    accept CompletePrebreath
                    then depressurization;
                transition depressurization_to_egress
                    first depressurization
                    accept Depressurized
                    then egress;
                transition egress_to_operations
                    first egress
                    accept EgressComplete
                    then operations;
                transition operations_to_ingress
                    first operations
                    accept MissionComplete
                    then ingress;
                transition ingress_to_repressurization
                    first ingress
                    accept IngressComplete
                    then repressurization;
                transition repressurization_to_standby
                    first repressurization
                    accept Repressurized
                    then standby;
            }
            
            exhibit state healthMonitoring parallel {
                entry action initial;
                state nominal;
                state degraded;
                state critical;
                transition initial then nominal;
                transition nominal_to_degraded
                    first nominal
                    accept Warning
                    then degraded;
                transition degraded_to_critical
                    first degraded
                    accept CriticalAlert
                    then critical;
                transition degraded_to_nominal
                    first degraded
                    accept Reset
                    then nominal;
            }
            
            part plss : PLSS;
            part pressureGarment : PressureGarmentAssembly;
            part helmet : HelmetAndVisorAssembly;
            part gloves : ExtravehicularGloves;
            part commCarrier : CommunicationCarrierAssembly;
            part dcm : DisplayAndControlModule;
            part tether : SafetyTether;
            part safer : SAFER;
            
            flow : Flows::OxygenFlow from plss.oxygenOut to pressureGarment.oxygenIn;
            flow : Flows::OxygenFlow from plss.oxygenOut to helmet.oxygenIn;
            flow : Flows::CO2Flow from pressureGarment.co2Out to plss.co2In;
            flow : Flows::CoolantFlow from plss.coolantOut to pressureGarment.coolantIn;
            flow : Flows::CoolantFlow from pressureGarment.coolantReturn to plss.coolantInReturn;
            flow : Flows::PowerFlow from plss.powerOut to dcm.powerIn;
            flow : Flows::PowerFlow from plss.powerOut to gloves.powerIn;
            flow : Flows::DataFlow from commCarrier.dataOut to dcm.dataIn;
        }
    }
    
    package Requirements {
        requirement def LifeSupportRequirement {
            doc /* The EMU shall provide breathable oxygen and remove CO2. */
            subject emu : Parts::EMU;
        }
        requirement def PressureRequirement {
            doc /* The EMU shall maintain a pressurized environment. */
            subject emu : Parts::EMU;
        }
        requirement def ThermalProtectionRequirement {
            doc /* The EMU shall protect against temperature extremes and debris. */
            subject emu : Parts::EMU;
        }
        requirement def CommunicationRequirement {
            doc /* The EMU shall provide constant communication. */
            subject emu : Parts::EMU;
        }
        requirement def SafetyRequirement {
            doc /* The EMU shall include a tether and SAFER for rescue. */
            subject emu : Parts::EMU;
        }
    }
}
