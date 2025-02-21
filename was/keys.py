#!/usr/bin/env python
# -*- coding: utf-8 -*-

misp_url = 'https://misp-core'
misp_key = 'F2X7J51IUCAtE9lsYQCv2y05dKqMNGbGIq1SmPug' # The MISP auth key can be found on the MISP web interface under the automation section
misp_verifycert = False
misp_client_cert = ''
proofpoint_sp = '<proofpoint service principal>'  # Service Principal from TAP (https://threatinsight.proofpoint.com/<custID>/settings/connected-applications)
proofpoint_secret = '<proofpoint secret>'