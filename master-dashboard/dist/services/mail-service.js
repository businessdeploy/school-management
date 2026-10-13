"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MailService = void 0;
const nodemailer_1 = __importDefault(require("nodemailer"));
const config_1 = require("../config");
class MailService {
    static transporter = null;
    static init() {
        if (config_1.config.smtp && config_1.config.smtp.host) {
            try {
                this.transporter = nodemailer_1.default.createTransport({
                    host: config_1.config.smtp.host,
                    port: config_1.config.smtp.port,
                    secure: config_1.config.smtp.secure,
                    auth: config_1.config.smtp.user && config_1.config.smtp.pass
                        ? {
                            user: config_1.config.smtp.user,
                            pass: config_1.config.smtp.pass,
                        }
                        : undefined,
                    tls: {
                        rejectUnauthorized: config_1.config.env === 'production',
                    },
                });
                console.log(`[MailService] Initialized SMTP transport -> ${config_1.config.smtp.host}:${config_1.config.smtp.port}`);
            }
            catch (err) {
                console.error('[MailService] Failed to initialize SMTP transport:', err.message);
                this.transporter = null;
            }
        }
        else {
            console.log('[MailService] No SMTP_HOST configured. Magic links will be logged to console and displayed in UI.');
            this.transporter = null;
        }
    }
    static async sendMagicLoginEmail(options) {
        const { to, username, magicLink } = options;
        if (!this.transporter && config_1.config.smtp && config_1.config.smtp.host) {
            this.init();
        }
        const html = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Prime School Control Plane Access</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #090d16; color: #f1f5f9; margin: 0; padding: 40px 16px; }
          .container { max-width: 540px; margin: 0 auto; background: #0f172a; border: 1px solid #1e293b; border-radius: 20px; padding: 36px; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5); }
          .logo { display: inline-flex; align-items: center; justify-content: center; width: 44px; height: 44px; background: linear-gradient(135deg, #4f46e5, #7c3aed); border-radius: 12px; font-size: 22px; color: #ffffff; margin-bottom: 24px; }
          h1 { font-size: 20px; font-weight: 700; color: #ffffff; margin: 0 0 10px 0; }
          p { font-size: 14px; line-height: 1.6; color: #94a3b8; margin: 0 0 20px 0; }
          .button { display: inline-block; padding: 14px 28px; background: linear-gradient(135deg, #4f46e5, #6366f1); color: #ffffff !important; border-radius: 12px; text-decoration: none; font-weight: 600; font-size: 14px; margin: 12px 0 24px 0; box-shadow: 0 10px 15px -3px rgba(79, 70, 229, 0.3); }
          .footer { font-size: 12px; color: #64748b; border-top: 1px solid #1e293b; padding-top: 20px; margin-top: 20px; word-break: break-all; }
          .badge { display: inline-block; padding: 4px 10px; background: rgba(99, 102, 241, 0.1); border: 1px solid rgba(99, 102, 241, 0.2); border-radius: 6px; color: #818cf8; font-size: 12px; font-weight: 500; margin-bottom: 16px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="logo">⚡</div>
          <div class="badge">Prime School Fleet Control</div>
          <h1>Passwordless Sign-In Request</h1>
          <p>Hello <strong>${username}</strong>,</p>
          <p>We received a sign-in request for your Prime School Fleet Master Dashboard. Click the button below to securely authenticate your session:</p>
          <div style="text-align: center;">
            <a href="${magicLink}" class="button" target="_blank">🚀 Log In to Master Dashboard</a>
          </div>
          <p style="font-size: 13px; color: #f59e0b;">⏳ This sign-in link is single-use and will expire in 15 minutes.</p>
          <p style="font-size: 12px; color: #64748b;">If you did not request this link, no action is needed. Your account remains completely secure.</p>
          <div class="footer">
            <p style="margin-bottom: 6px;">Button not working? Copy and paste this link into your browser:</p>
            <a href="${magicLink}" style="color: #6366f1; text-decoration: underline;">${magicLink}</a>
          </div>
        </div>
      </body>
      </html>
    `;
        const text = `
Prime School Fleet Master Dashboard - Passwordless Sign-In
=========================================================

Hello ${username},

Click the link below to securely log in to your Prime School Master Dashboard:
${magicLink}

This link is valid for 15 minutes and can only be used once.

If you did not request this email, please disregard it.
    `.trim();
        if (!this.transporter) {
            console.log('================================================================');
            console.log(`[MailService] MAGIC SIGN-IN LINK FOR "${to}":`);
            console.log(`👉 ${magicLink}`);
            console.log('================================================================');
            return {
                sent: false,
                reason: 'smtp_not_configured',
            };
        }
        try {
            const info = await this.transporter.sendMail({
                from: config_1.config.smtp.from,
                to,
                subject: '⚡ Prime School Master Dashboard - Secure Sign-In Link',
                text,
                html,
            });
            console.log(`[MailService] Magic link successfully sent to ${to}. MessageId: ${info.messageId}`);
            return {
                sent: true,
                messageId: info.messageId,
            };
        }
        catch (err) {
            console.error(`[MailService] Error sending email to ${to}:`, err.message);
            console.log('================================================================');
            console.log(`[MailService FALLBACK] MAGIC SIGN-IN LINK FOR "${to}":`);
            console.log(`👉 ${magicLink}`);
            console.log('================================================================');
            return {
                sent: false,
                reason: err.message,
            };
        }
    }
}
exports.MailService = MailService;
