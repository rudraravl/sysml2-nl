package QuantumDotPhotonEmissionSystem {

    // ---- Value Types with Units ----
    import ScalarValues::*;
    
    value def Wavelength :> Real { 
        unit nm; 
        doc "Wavelength of light in nanometers." 
    }
    
    value def Power :> Real { 
        unit mW; 
        doc "Optical power in milliwatts." 
    }
    
    value def Temperature :> Real { 
        unit '°C'; 
        doc "Temperature in degrees Celsius." 
    }
    
    value def TemperatureF :> Real { 
        unit '°F'; 
        doc "Temperature in degrees Fahrenheit." 
    }
    
    value def Diameter :> Real { 
        unit nm; 
        doc "Particle diameter in nanometers." 
    }
    
    value def SpectralPurity :> Real { 
        unit percent; 
        doc "Percentage of emitted light at target wavelength." 
    }
    
    value def CountRate :> Real { 
        unit 'ph/s'; 
        doc "Photon count rate." 
    }

    // ---- Item Types ----
    item def Photon {
        attribute wavelength : Wavelength;
        attribute power : Power;
        attribute color : String;
    }
    
    item def UVPhoton :> Photon {
        redefines color = "ultraviolet";
    }
    
    item def GreenPhoton :> Photon {
        redefines color = "green";
    }

    // ---- Port Definitions ----
    port def OpticalPort {
        out item photons : Photon;
        in item feedback : Photon;
    }
    
    port def UVPort {
        out item uvPhotons : UVPhoton;
    }
    
    port def GreenPort {
        in item greenPhotons : GreenPhoton;
    }
    
    port def ThermalPort {
        in attribute setpoint : Temperature;
        out attribute measuredTemp : Temperature;
    }

    // ---- Requirements ----
    requirement def EmissionRequirement {
        doc "The system shall convert UV excitation into pure green photons."
        attribute targetWavelength : Wavelength = 530[nm];
        attribute minSpectralPurity : SpectralPurity = 95[percent];
        subject emittedLight : Photon;
        require emittedLight.wavelength == targetWavelength
    }
    
    requirement def TemperatureStabilityRequirement {
        doc "Quantum dot temperature shall be maintained at 25°C ± 0.5°C."
        attribute targetTemp : Temperature = 25['°C'];
        attribute tolerance : Temperature = 0.5['°C'];
        subject dotTemp : Temperature;
        require dotTemp >= targetTemp - tolerance and dotTemp <= targetTemp + tolerance
    }
    
    requirement def ExcitationRequirement {
        doc "Excitation source shall emit UV photons at 405 nm."
        attribute uvWavelength : Wavelength = 405[nm];
        attribute minPower : Power = 50[mW];
        subject uvLight : UVPhoton;
        require uvLight.wavelength == uvWavelength and uvLight.power >= minPower
    }
    
    requirement def FilteringRequirement {
        doc "Optical filter shall block UV light and pass green light."
        attribute blockWavelength : Wavelength = 405[nm];
        attribute passWavelength : Wavelength = 530[nm];
        subject filter : OpticalFilter;
    }

    // ---- Parts ----
    
    part def ExcitationSource {
        port out uvOut : UVPort;
        attribute outputWavelength : Wavelength = 405[nm];
        attribute outputPower : Power = 100[mW];
        attribute status : String = "on";
        
        action def EmitUV :> Action {
            out photon : UVPhoton;
        }
        
        perform EmitUV;
    }
    
    part def QuantumDot {
        port in uvIn : UVPort;
        port out greenOut : OpticalPort;
        port thermal : ThermalPort;
        
        attribute material : String = "Cadmium Selenide";
        attribute diameter : Diameter = 5[nm];
        attribute emissionWavelength : Wavelength = 530[nm];
        attribute operatingTemp : Temperature = 25['°C'];
        attribute state : String;
        
        state defdotState {
            initialState ground;
            state excited;
            transition ground->excited 
                when uvIn.uvPhotons->notEmpty()
                accept uvIn.uvPhotons;
            transition excited->ground 
                when excited.active
                emit greenOut.photons;
        }
        
        exhibit dotState;
        
        action def Absorb :> Action {
            in uv : UVPhoton;
        }
        
        action def Emit :> Action {
            out green : GreenPhoton;
        }
    }
    
    part def OpticalFilter {
        port in filterIn : OpticalPort;
        port out filterOut : OpticalPort;
        
        attribute passbandCenter : Wavelength = 530[nm];
        attribute passbandWidth : Wavelength = 20[nm];
        attribute blockband : Wavelength = 405[nm];
        attribute transmission : Real = 0.98;
        
        action def Filter :> Action {
            in mixed : Photon;
            out pure : GreenPhoton;
        }
        
        perform Filter;
    }
    
    part def PhotoDetector {
        port in detectorIn : GreenPort;
        
        attribute measuredWavelength : Wavelength;
        attribute measuredIntensity : Power;
        attribute measuredPurity : SpectralPurity;
        attribute countRate : CountRate;
        
        action def Measure :> Action {
            in green : GreenPhoton;
            out wavelength : Wavelength;
            out intensity : Power;
            out purity : SpectralPurity;
        }
        
        perform Measure;
    }
    
    part def TemperatureController {
        port thermalCtrl : ThermalPort;
        
        attribute setpoint : Temperature = 25['°C'];
        attribute setpointF : TemperatureF = 77['°F'];
        attribute currentTemp : Temperature;
        attribute heaterPower : Power;
        attribute tolerance : Temperature = 0.5['°C'];
        
        state def controllerState {
            initialState idle;
            state heating;
            state cooling;
            transition idle->heating 
                when currentTemp < setpoint - tolerance;
            transition heating->idle 
                when currentTemp >= setpoint - tolerance;
            transition idle->cooling 
                when currentTemp > setpoint + tolerance;
            transition cooling->idle 
                when currentTemp <= setpoint + tolerance;
        }
        
        exhibit controllerState;
        
        action def Regulate :> Action {
            in measured : Temperature;
            out command : Power;
        }
        
        perform Regulate;
    }

    // ---- System Assembly ----
    part def QuantumDotEmissionSystem {
        part excitationSource : ExcitationSource {
            satisfy ExcitationRequirement;
        }
        
        part quantumDot : QuantumDot {
            satisfy EmissionRequirement;
            satisfy TemperatureStabilityRequirement;
        }
        
        part opticalFilter : OpticalFilter {
            satisfy FilteringRequirement;
        }
        
        part photoDetector : PhotoDetector;
        
        part temperatureController : TemperatureController {
            satisfy TemperatureStabilityRequirement;
        }
        
        // Optical connections
        connection uvPath : UVPort 
            connect excitationSource.uvOut to quantumDot.uvIn;
        
        connection dotToFilter : OpticalPort 
            connect quantumDot.greenOut to opticalFilter.filterIn;
        
        connection filterToDetector : OpticalPort 
            connect opticalFilter.filterOut to photoDetector.detectorIn;
        
        // Thermal control connection
        connection thermalLoop : ThermalPort 
            connect temperatureController.thermalCtrl to quantumDot.thermal;
    }

}
