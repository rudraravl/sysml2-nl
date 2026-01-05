package AmmoniaphoneSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AmmoniaConcentration :> ISQ::AmountOfSubstanceConcentrationValue;
    attribute def AcousticFrequency :> ISQ::FrequencyValue;
    attribute def AcousticPressure :> ISQ::PressureValue;
    attribute def FlowRate :> ISQ::VolumeFlowRateValue;
    attribute def ElectricalVoltage :> ISQ::ElectricPotentialValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    
    attribute def StartCommand;
    attribute def StopCommand;
    
    item def AmmoniaGas {
        attribute concentration : AmmoniaConcentration;
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRate;
    }
    
    item def AcousticWave {
        attribute frequency : AcousticFrequency;
        attribute amplitude : AcousticPressure;
    }
    
    port def AmmoniaInputPort {
        in item ammoniaFlow : AmmoniaGas;
    }
    
    port def AcousticOutputPort {
        out item soundWave : AcousticWave;
    }
    
    port def ControlPort {
        in attribute controlVoltage : ElectricalVoltage;
    }
    
    part def AmmoniaReservoir {
        port outlet : AmmoniaInputPort;
        attribute capacity :> ISQ::volume;
        attribute storedConcentration : AmmoniaConcentration;
    }
    
    action def RegulateFlowAction {
        in requestedVoltage : ElectricalVoltage;
        in incomingFlow : AmmoniaGas;
        out regulatedFlow : AmmoniaGas;
    }
    
    part def FlowRegulator {
        port inlet : AmmoniaInputPort;
        port outlet : AmmoniaInputPort;
        port control : ControlPort;
        attribute regulatedFlowRate : FlowRate;
    }
    
    action def HeatAmmoniaAction {
        in coldGas : AmmoniaGas;
        out heatedGas : AmmoniaGas;
    }
    
    part def HeatingChamber {
        port ammoniaIn : AmmoniaInputPort;
        attribute chamberTemperature : TemperatureValue;
        attribute chamberPressure :> ISQ::pressure;
        attribute heatingPower :> ISQ::power;
    }
    
    action def GenerateToneAction {
        in excitedGas : AmmoniaGas;
        out acousticOutput : AcousticWave;
    }
    
    part def ResonanceCavity {
        port gasIn : AmmoniaInputPort;
        port soundOut : AcousticOutputPort;
        attribute resonantFrequency : AcousticFrequency;
        attribute cavityLength :> ISQ::length;
        attribute cavityDiameter :> ISQ::length;
    }
    
    action def AmplifySoundAction {
        in inputWave : AcousticWave;
        out amplifiedWave : AcousticWave;
    }
    
    part def AmplificationBell {
        port acousticIn : AcousticOutputPort;
        port acousticOut : AcousticOutputPort;
        attribute amplificationFactor : Real;
        attribute bellDiameter :> ISQ::length;
    }
    
    action def GenerateControlSignalAction {
        in desiredFrequency : AcousticFrequency;
        in desiredAmplitude : AcousticPressure;
        out controlVoltage : ElectricalVoltage;
    }
    
    part def ControlUnit {
        port controlOut : ControlPort;
        attribute targetFrequency : AcousticFrequency;
        attribute targetAmplitude : AcousticPressure;
    }
    
    part def Ammoniaphone {
        port ammoniaSupply : AmmoniaInputPort;
        port acousticOutput : AcousticOutputPort;
        port externalControl : ControlPort;
        
        part reservoir : AmmoniaReservoir;
        part regulator : FlowRegulator;
        part heater : HeatingChamber;
        part cavity : ResonanceCavity;
        part bell : AmplificationBell;
        part controller : ControlUnit;
        
        connect reservoir.outlet to regulator.inlet;
        connect regulator.outlet to heater.ammoniaIn;
        connect heater to cavity.gasIn;
        connect cavity.soundOut to bell.acousticIn;
        connect bell.acousticOut to acousticOutput;
        connect controller.controlOut to regulator.control;
        connect externalControl to controller.controlOut;
        
        action def ProduceTone {
            in targetFrequency : AcousticFrequency;
            in targetAmplitude : AcousticPressure;
            out generatedSound : AcousticWave;
            
            first start;
            then action generateControl : GenerateControlSignalAction {
                in desiredFrequency = targetFrequency;
                in desiredAmplitude = targetAmplitude;
                out controlVoltage;
            }
            then action regulate : RegulateFlowAction {
                in requestedVoltage = generateControl.controlVoltage;
                in incomingFlow;
                out regulatedFlow;
            }
            then action heat : HeatAmmoniaAction {
                in coldGas = regulate.regulatedFlow;
                out heatedGas;
            }
            then action resonate : GenerateToneAction {
                in excitedGas = heat.heatedGas;
                out acousticOutput;
            }
            then action amplify : AmplifySoundAction {
                in inputWave = resonate.acousticOutput;
                out amplifiedWave;
            }
            then assign generatedSound := amplify.amplifiedWave;
            then done;
        }
        
        state machine OperationalStates {
            initial state Idle;
            state Warming;
            state Playing;
            state Cooling;
            
            transition idle_to_warming
                first Idle
                accept StartCommand
                then Warming;
            
            transition warming_to_playing
                first Warming
                if heater.chamberTemperature >= 300.0
                then Playing;
            
            transition playing_to_cooling
                first Playing
                accept StopCommand
                then Cooling;
            
            transition cooling_to_idle
                first Cooling
                if heater.chamberTemperature <= 290.0
                then Idle;
            
            state Playing {
                entry action {
                    perform ProduceTone;
                }
            }
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The Ammoniaphone shall convert controlled ammonia gas flow into audible acoustic tones. */
        subject ammoniaphone : Ammoniaphone;
    }
    
    requirement def FrequencyRangeRequirement {
        doc /* The Ammoniaphone shall produce acoustic frequencies between 200 Hz and 2000 Hz. */
        subject ammoniaphone : Ammoniaphone;
        
        require constraint FrequencyBounds {
            ammoniaphone.acousticOutput.soundWave.frequency >= 200.0 and
            ammoniaphone.acousticOutput.soundWave.frequency <= 2000.0
        }
    }
    
    requirement def AmplitudeRequirement {
        doc /* The Ammoniaphone shall produce acoustic pressure levels between 60 dB and 100 dB SPL. */
        subject ammoniaphone : Ammoniaphone;
        
        require constraint AmplitudeBounds {
            ammoniaphone.acousticOutput.soundWave.amplitude >= 20.0e-6 and
            ammoniaphone.acousticOutput.soundWave.amplitude <= 2.0
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The Ammoniaphone shall maintain ammonia concentration below hazardous levels during operation. */
        subject ammoniaphone : Ammoniaphone;
        
        require constraint SafeConcentration {
            ammoniaphone.reservoir.storedConcentration <= 25.0
        }
    }
    
    part ammoniaphoneSystem : Ammoniaphone {
        satisfy PrimaryFunctionRequirement;
        satisfy FrequencyRangeRequirement;
        satisfy AmplitudeRequirement;
        satisfy SafetyRequirement;
    }
    
    action def OperateAmmoniaphone {
        in operatingFrequency : AcousticFrequency;
        in operatingAmplitude : AcousticPressure;
        out producedSound : AcousticWave;
        
        perform ammoniaphoneSystem.ProduceTone {
            in targetFrequency = operatingFrequency;
            in targetAmplitude = operatingAmplitude;
            out generatedSound;
        }
        then assign producedSound := ammoniaphoneSystem.ProduceTone.generatedSound;
    }
}
