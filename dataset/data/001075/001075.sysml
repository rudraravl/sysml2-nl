package GroundSpeedRadarSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def RadarFrequency :> ISQ::FrequencyValue;
    attribute def DopplerShift :> ISQ::FrequencyValue;
    attribute def BeamAngle :> ISQ::AngleValue;
    attribute def SignalStrength :> ScalarValues::Real;

    item def TransmittedSignal {
        attribute carrierFrequency : RadarFrequency;
        attribute transmitPower : ISQ::PowerValue;
        attribute beamAngle : BeamAngle;
        attribute timestamp : ISQ::TimeValue;
    }

    item def ReceivedSignal {
        attribute receivedFrequency : RadarFrequency;
        attribute receivedPower : ISQ::PowerValue;
        attribute dopplerShift : DopplerShift;
        attribute signalQuality : SignalStrength;
    }

    item def VelocityMeasurement {
        attribute groundSpeed : ISQ::SpeedValue;
        attribute measurementAccuracy : ISQ::SpeedValue;
        attribute validFlag : ScalarValues::Boolean;
        attribute timestamp : ISQ::TimeValue;
    }

    item def PowerOnCommand;
    item def StandbyCommand;
    item def ResumeCommand;
    item def ResetCommand;
    item def FaultDetected;
    item def MeasurementCycle;

    port def TransmitPort {
        out item txSignal : TransmittedSignal;
    }

    port def ReceivePort {
        in item rxSignal : ReceivedSignal;
    }

    port def VelocityOutputPort {
        out item velocity : VelocityMeasurement;
    }

    port def PowerInputPort {
        in attribute voltage : ISQ::ElectricPotentialDifferenceValue;
        in attribute current : ISQ::ElectricCurrentValue;
    }

    part def RFTransmitter {
        port txPort : TransmitPort;
        port powerIn : PowerInputPort;

        attribute operatingFrequency : RadarFrequency;
        attribute outputPower : ISQ::PowerValue;

        action generateRFSignal {
            in frequency : RadarFrequency;
            in power : ISQ::PowerValue;
            out signal : TransmittedSignal;
        }
    }

    part def RFReceiver {
        port rxPort : ReceivePort;
        port powerIn : PowerInputPort;

        attribute sensitivity : ISQ::PowerValue;
        attribute bandwidthFilter : RadarFrequency;

        action receiveRFSignal {
            in signal : ReceivedSignal;
            out processedSignal : ReceivedSignal;
        }
    }

    part def DopplerProcessor {
        port powerIn : PowerInputPort;

        attribute speedOfLight : ISQ::SpeedValue;

        action calculateDopplerShift {
            in transmittedFreq : RadarFrequency;
            in receivedFreq : RadarFrequency;
            out dopplerFreq : DopplerShift;
        }

        action computeGroundSpeed {
            in dopplerFreq : DopplerShift;
            in carrierFreq : RadarFrequency;
            in beamAngle : BeamAngle;
            out speed : ISQ::SpeedValue;
        }
    }

    part def AntennaSystem {
        attribute antennaGain : ScalarValues::Real;
        attribute beamWidth : BeamAngle;
        attribute mountAngle : BeamAngle;
        attribute polarization : ScalarValues::String;

        action transmitToGround {
            in signal : TransmittedSignal;
        }

        action receiveFromGround {
            out signal : ReceivedSignal;
        }
    }

    part def PowerSupplyUnit {
        port powerOut1 : PowerInputPort;
        port powerOut2 : PowerInputPort;
        port powerOut3 : PowerInputPort;

        attribute inputVoltage : ISQ::ElectricPotentialDifferenceValue;
        attribute outputVoltage : ISQ::ElectricPotentialDifferenceValue;
        attribute maxCurrent : ISQ::ElectricCurrentValue;

        action regulatePower {
            in inputV : ISQ::ElectricPotentialDifferenceValue;
            out outputV : ISQ::ElectricPotentialDifferenceValue;
            out outputI : ISQ::ElectricCurrentValue;
        }
    }

    action def MeasureGroundVelocity {
        in carrierFrequency : RadarFrequency;
        in transmitPower : ISQ::PowerValue;
        in antennaAngle : BeamAngle;
        out measuredVelocity : ISQ::SpeedValue;
        out measurementValid : ScalarValues::Boolean;

        first start;
        then action transmit {
            in freq : RadarFrequency = carrierFrequency;
            in power : ISQ::PowerValue = transmitPower;
            out txSignal : TransmittedSignal;
        }
        then action propagate {
            in signal : TransmittedSignal = transmit.txSignal;
        }
        then action reflect {
            in incidentSignal : TransmittedSignal = transmit.txSignal;
            out reflectedSignal : ReceivedSignal;
        }
        then action receive {
            in rxSignal : ReceivedSignal = reflect.reflectedSignal;
            out processedRx : ReceivedSignal;
        }
        then action extractDoppler {
            in txFreq : RadarFrequency = transmit.txSignal.carrierFrequency;
            in rxFreq : RadarFrequency = receive.processedRx.receivedFrequency;
            out doppler : DopplerShift;
        }
        then action calculateVelocity {
            in dopplerShift : DopplerShift = extractDoppler.doppler;
            in carrierFreq : RadarFrequency = carrierFrequency;
            in angle : BeamAngle = antennaAngle;
            out velocity : ISQ::SpeedValue;
        }
        then action validate {
            in speed : ISQ::SpeedValue = calculateVelocity.velocity;
            in signalQuality : SignalStrength = receive.processedRx.signalQuality;
            out isValid : ScalarValues::Boolean;
        }
        then assign measuredVelocity := calculateVelocity.velocity;
        then assign measurementValid := validate.isValid;
        then done;
    }

    state def RadarSystemStates {
        entry; then powerOff;

        state powerOff {
            entry assign systemActive := false;
        }

        transition powerOff_to_initialization
            first powerOff
            accept powerOn : PowerOnCommand
            then initialization;

        state initialization {
            entry assign systemActive := true;
            do action selfTest;
            do action calibrateSystem;
        }

        transition initialization_to_operational
            first initialization
            if initializationComplete
            then operational;

        state operational {
            do action continuousMeasurement : MeasureGroundVelocity;

            state idle {
                entry assign transmitterEnabled := false;
            }

            state transmitting {
                entry assign transmitterEnabled := true;
                do action emitRadarPulse;
            }

            state receiving {
                do action captureReflection;
            }

            state computing {
                do action processDopplerData;
            }

            state outputting {
                do action publishVelocity;
            }

            transition idle_to_transmitting
                first idle
                accept cycle : MeasurementCycle
                then transmitting;

            transition transmitting_to_receiving
                first transmitting
                if pulseComplete
                then receiving;

            transition receiving_to_computing
                first receiving
                if signalCaptured
                then computing;

            transition computing_to_outputting
                first computing
                if velocityComputed
                then outputting;

            transition outputting_to_idle
                first outputting
                then idle;
        }

        transition operational_to_standby
            first operational
            accept standby : StandbyCommand
            then standby;

        state standby {
            entry assign transmitterEnabled := false;
        }

        transition standby_to_operational
            first standby
            accept resume : ResumeCommand
            then operational;

        state fault {
            do action logFault;
            do action disableTransmitter;
            do action notifyOperator;
        }

        transition powerOff_to_fault
            first powerOff
            accept faultEvent : FaultDetected
            then fault;

        transition initialization_to_fault
            first initialization
            accept faultEvent : FaultDetected
            then fault;

        transition operational_to_fault
            first operational
            accept faultEvent : FaultDetected
            then fault;

        transition standby_to_fault
            first standby
            accept faultEvent : FaultDetected
            then fault;

        transition fault_to_powerOff
            first fault
            accept reset : ResetCommand
            then powerOff;

        attribute systemActive : ScalarValues::Boolean;
        attribute transmitterEnabled : ScalarValues::Boolean;
        attribute initializationComplete : ScalarValues::Boolean;
        attribute pulseComplete : ScalarValues::Boolean;
        attribute signalCaptured : ScalarValues::Boolean;
        attribute velocityComputed : ScalarValues::Boolean;
    }

    part def GroundSpeedRadarSystem {
        doc /*
         * Ground Speed Radar System
         * 
         * Primary Function:
         * The Ground Speed Radar System measures the true velocity of a vehicle
         * relative to the ground surface using Doppler radar principles. The system
         * transmits a microwave signal at a known frequency toward the ground at an
         * oblique angle. As the vehicle moves, the reflected signal experiences a
         * frequency shift proportional to the vehicle's ground speed due to the
         * Doppler effect.
         * 
         * By precisely measuring this frequency shift and applying the Doppler
         * equation with the known beam angle and carrier frequency, the system
         * calculates the vehicle's true ground speed independent of wheel slip,
         * GPS availability, or inertial drift.
         * 
         * This provides critical velocity information for navigation systems,
         * flight control in aircraft, automotive safety systems, and any application
         * requiring accurate ground-referenced speed measurement.
         */

        part transmitter : RFTransmitter {
            attribute :>> operatingFrequency = 24.125 [SI::GHz];
            attribute :>> outputPower = 0.1 [SI::W];
        }

        part receiver : RFReceiver {
            attribute :>> sensitivity = 1.0e-12 [SI::W];
            attribute :>> bandwidthFilter = 100.0 [SI::kHz];
        }

        part processor : DopplerProcessor {
            attribute :>> speedOfLight = 299792458.0 [SI::m/SI::s];
        }

        part antenna : AntennaSystem {
            attribute :>> antennaGain = 18.0;
            attribute :>> beamWidth = 25.0 [SI::deg];
            attribute :>> mountAngle = 45.0 [SI::deg];
            attribute :>> polarization = "vertical";
        }

        part powerSupply : PowerSupplyUnit {
            attribute :>> inputVoltage = 28.0 [SI::V];
            attribute :>> outputVoltage = 12.0 [SI::V];
            attribute :>> maxCurrent = 5.0 [SI::A];
        }

        port velocityOutput : VelocityOutputPort;

        connection powerToTransmitter connect powerSupply.powerOut1 to transmitter.powerIn;
        connection powerToReceiver connect powerSupply.powerOut2 to receiver.powerIn;
        connection powerToProcessor connect powerSupply.powerOut3 to processor.powerIn;

        connection txToAntenna connect transmitter.txPort to antenna;
        connection antennaToRx connect antenna to receiver.rxPort;

        perform action measureVelocity : MeasureGroundVelocity {
            in carrierFrequency = transmitter.operatingFrequency;
            in transmitPower = transmitter.outputPower;
            in antennaAngle = antenna.mountAngle;
            out measuredVelocity;
            out measurementValid;
        }

        exhibit state systemState : RadarSystemStates;
    }

    requirement def GroundSpeedMeasurementCapability {
        doc /*
         * The system shall measure ground speed using Doppler radar
         * with specified accuracy and update rate.
         */

        subject radarSystem : GroundSpeedRadarSystem;

        require constraint accuracyConstraint {
            doc /*
             * Ground speed measurement accuracy shall be within ±0.2 m/s
             * for speeds ranging from 0 to 250 m/s.
             */
        }

        require constraint updateRateConstraint {
            doc /*
             * The system shall provide velocity measurements at a minimum
             * update rate of 10 Hz during operational state.
             */
        }

        require constraint operationalAltitudeConstraint {
            doc /*
             * The system shall operate correctly at altitudes from ground
             * level to 15000 meters above ground level.
             */
        }
    }

    requirement def SystemReliability {
        doc /*
         * The system shall maintain operational reliability and
         * fault detection capabilities.
         */

        subject radarSystem : GroundSpeedRadarSystem;

        require constraint faultDetectionConstraint {
            doc /*
             * The system shall detect and report critical faults within
             * 100 milliseconds of occurrence.
             */
        }

        require constraint availabilityConstraint {
            doc /*
             * The system shall achieve 99.9% availability during
             * powered operation under normal environmental conditions.
             */
        }
    }

    part groundSpeedRadar : GroundSpeedRadarSystem;

    requirement primaryCapability : GroundSpeedMeasurementCapability {
        subject radarSystem = groundSpeedRadar;
    }

    requirement reliability : SystemReliability {
        subject radarSystem = groundSpeedRadar;
    }
}
