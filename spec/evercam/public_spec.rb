require 'data_helper'

describe 'Evercam::API Public Methods' do
   let(:api) {
      Evercam::API.new(api_id: '123456', api_key: '1a2b3c4d5e6a7b8c9d0e')
   }

   describe '#get_public_cameras' do
      it 'returns an array when the API call returns success' do
         stub_request(:get, "https://api.evercam.io/v1/public/cameras.json?api_id=123456&api_key=1a2b3c4d5e6a7b8c9d0e").
            to_return(:status => 200, :body => '{"cameras": [], "pages": 1}', :headers => {})

         data = api.get_public_cameras
         expect(data).not_to be_nil
         expect(data.class).to eq(Hash)
         expect(data.include?(:cameras)).to eq(true)
         expect(data.include?(:pages)).to eq(true)
         expect(data[:cameras]).to eq([])
         expect(data[:pages]).to eq(1)
      end

      it 'raises an exception when the API call returns an error' do
         stub_request(:get, "https://api.evercam.io/v1/public/cameras.json?api_id=123456&api_key=1a2b3c4d5e6a7b8c9d0e").
            to_return(:status => 400, :body => '{"message": "Failed"}', :headers => {})

         expect {api.get_public_cameras}.to raise_error(Evercam::EvercamError,
                                                        "Failed")
      end

      it 'raises an exception when the API call response contains no data' do
         stub_request(:get, "https://api.evercam.io/v1/public/cameras.json?api_id=123456&api_key=1a2b3c4d5e6a7b8c9d0e").
            to_return(:status => 200, :body => '{}', :headers => {})

         expect {api.get_public_cameras}.to raise_error(Evercam::EvercamError,
                                                        "Invalid response received from server.")
      end
   end
end