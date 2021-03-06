

require 'driven_sip_test_case'


class TestMultiHomedWithDetached < DrivenSipTestCase

  def setup
    @tp = SipperConfigurator[:LocalTestPort]
    SipperConfigurator[:LocalTestPort] = [5066, 5067]
    super
    str = <<-EOF
    
    require 'sip_test_driver_controller'
    
    module TestMultiHomedWithDetached_SipInline
      class Uas1DetachedController < SIP::SipTestDriverController
      
        transaction_usage :use_transactions=>true
        
        def on_invite(session)
          session.respond_with(200)
          logd("Received INVITE sent a 200 from "+name)
        end
        
        def on_ack(session)
          session.request_with("bye")
        end
        
        def on_success_res(session)
          session.invalidate(true)
          session.flow_completed_for("TestMultiHomedWithDetached")
        end
        
        def order
          0
        end
        
      end
      
      class UacDetached1Controller < SIP::SipTestDriverController
      
        transaction_usage :use_transactions=>true  
        
        def specified_transport
          [SipperConfigurator[:LocalSipperIP], SipperConfigurator[:LocalTestPort][1] ]
        end
        
        def start
          r = Request.create_initial("invite", "sip:nasir@#{SipperConfigurator[:LocalSipperIP]}:#{SipperConfigurator[:LocalTestPort][0]}", :p_session_record=>"msg-info")
          ds = create_session
          ds.send(r)
          logd("Sent a new INVITE from "+name)
        end
     
        
        def on_success_res(session)
          session.do_record(session.transport.port)
          session.request_with('ACK')
        end
        
        def on_bye(session)
          session.respond_with(200)
          session.invalidate(true)
        end
         
      end
    end
    EOF
    define_controller_from(str)
    set_controller("TestMultiHomedWithDetached_SipInline::UacDetached1Controller")
  end
  
  
  def test_detached_controller
    self.expected_flow = ["> INVITE", "< 100", "< 200", "! 5067", "> ACK", "< BYE", "> 200"]
    start_controller
    verify_call_flow(:out)
    self.expected_flow = ["< INVITE", "> 100", "> 200", "< ACK", "> BYE", "< 200"]
    verify_call_flow(:in)
  end

  def teardown
    SipperConfigurator[:LocalTestPort] = @tp
    super
  end
  
end
